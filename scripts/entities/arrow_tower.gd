extends Building
## 箭塔：自动索敌，向射程内最近的敌人发射弹丸
## 满级分支二选一：快速射击箭塔（攻速极快）/ 大范围射击箭塔（射程扩大、伤害提升）

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var range_cells := 5.0
var damage := 19.0
var fire_interval := 0.5
var proj_speed := 640.0

var _base_damage := 0.0   # 1 级基础值（改造换分支时按等级重新成长）
var _base_range := 0.0
var _base_interval := 0.0

var _cd := 0.0
var _scan_cd := 0.0
var _target: Node2D = null
var _aim := -PI * 0.5
var _recoil := 0.0


func _ready() -> void:
	kind = GameConfig.Build.TOWER
	tint = GameConfig.C_TOWER
	max_hp = 260.0
	hp = max_hp
	max_level = GameConfig.MAX_LEVEL
	_base_damage = damage
	_base_range = range_cells
	_base_interval = fire_interval
	_cd = randf() * 0.2
	_scan_cd = randf() * 0.1


func _on_upgraded() -> void:
	super._on_upgraded()
	damage *= 1.5
	range_cells += 1.0
	_recoil = 6.0


# ============================================================
#  满级分支：快速射击 / 大范围射击
# ============================================================
func can_branch() -> bool:
	return level >= max_level and kind == GameConfig.Build.TOWER


func branch_options() -> Array:
	return [GameConfig.Build.TOWER_RAPID, GameConfig.Build.TOWER_RANGE]


func branch_cost() -> float:
	return GameConfig.BRANCH_COST


func branch_to(new_kind: int) -> bool:
	## 二选一定型：改 kind / 配色 / 数值并封顶，之后不可再升级
	if not can_branch():
		return false
	if not branch_options().has(new_kind):
		return false
	if not GameState.try_spend(GameConfig.BRANCH_COST):
		return false

	invested += GameConfig.BRANCH_COST
	max_level = level
	_apply_branch(new_kind)
	_up_pulse = 1.0
	_recoil = 6.0
	queue_redraw()
	return true


func _apply_branch(new_kind: int) -> void:
	## 按分支重置数值：先回到基础值按等级成长，再应用分支特性（改造换分支也走这里）
	kind = new_kind
	damage = _base_damage * pow(1.5, float(level - 1))
	range_cells = _base_range + float(level - 1)
	fire_interval = _base_interval
	match new_kind:
		GameConfig.Build.TOWER_RAPID:
			tint = GameConfig.C_TOWER_RAPID
			fire_interval = GameConfig.RAPID_INTERVAL
			_cd = 0.0
		GameConfig.Build.TOWER_RANGE:
			tint = GameConfig.C_TOWER_RANGE
			damage = ceilf(damage * GameConfig.RANGE_BRANCH_DMG_MUL)
			range_cells = GameConfig.RANGE_BRANCH_RANGE


func can_retrofit() -> bool:
	## 已定型且场上存在改造车间时可改为另一分支
	return kind != GameConfig.Build.TOWER and level >= max_level \
			and Board.has_kind(GameConfig.Build.RETOOL)


func retrofit_options() -> Array:
	var opts: Array = []
	for k in branch_options():
		if k != kind:
			opts.append(k)
	return opts


func retrofit_to(new_kind: int) -> bool:
	## 付费改为另一分支（保留等级，费用 = 分支定型价）
	if not can_retrofit() or not retrofit_options().has(new_kind):
		return false
	if not GameState.try_spend(retrofit_cost()):
		return false
	invested += retrofit_cost()
	_apply_branch(new_kind)
	_up_pulse = 1.0
	_recoil = 6.0
	queue_redraw()
	return true


func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	_scan_cd -= delta
	_recoil = maxf(0.0, _recoil - delta * 60.0)

	# 索敌节流：每 0.12 秒扫一次，避免每帧全表遍历
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target = _acquire()

	if _target != null and is_instance_valid(_target):
		var want := global_position.angle_to_point(_target.global_position)
		_aim = lerp_angle(_aim, want, clampf(delta * 14.0, 0.0, 1.0))
		if not silenced() and _cd <= 0.0 and _in_range(_target):
			_cd = fire_interval
			_shoot(_target)

	queue_redraw()


func _range_px() -> float:
	return range_cells * GameConfig.CELL


func _in_range(e: Node2D) -> bool:
	return global_position.distance_squared_to(e.global_position) <= _range_px() * _range_px()


func _acquire() -> Node2D:
	var best: Node2D = null
	var best_d := _range_px() * _range_px()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _shoot(e: Node2D) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position + Vector2(cos(_aim), sin(_aim)) * 12.0
	p.setup(e, damage * GameState.building_dmg_mul, proj_speed, tint, 0.0, self)
	layer.add_child(p)
	_recoil = 5.0


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 4.0

	# 底座平台
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.13, 0.23, 0.20), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.25), false, 2.0)
	draw_circle(Vector2.ZERO, half * 0.62, Color(col.r, col.g, col.b, 0.16))

	# 炮塔（三角，朝目标方向，射击时后坐）
	var dir := Vector2(cos(_aim), sin(_aim))
	var perp := Vector2(-dir.y, dir.x)
	var tip := dir * (13.0 - _recoil)
	var poly := PackedVector2Array([
		tip,
		perp * 7.5 - dir * 5.0,
		-perp * 7.5 - dir * 5.0,
	])
	draw_colored_polygon(poly, col)
	draw_circle(Vector2.ZERO, 4.0, col.lightened(0.45))

	_draw_hp_bar(24.0, -half - 8.0)
	super._draw()
