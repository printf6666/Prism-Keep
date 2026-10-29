extends Building
## 炮塔：重炮系塔，3 级后分支定型
##   · 基础形态：攻击射程内最近的敌人
##   · 重型炮：单发大量伤害，优先轰击血量上限最高的敌人
##   · 迫击炮：大射程曲射群伤，优先轰击敌人最密集处

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var range_cells := 4.5
var damage := 30.0
var fire_interval := 1.2
var proj_speed := 520.0
var splash_radius := 0.0   # >0 = 迫击炮（落点群伤）

var _base_damage := 0.0   # 1 级基础值（改造换分支时按等级重新成长）
var _base_range := 0.0
var _base_interval := 0.0

var _cd := 0.0
var _scan_cd := 0.0
var _target: Node2D = null        # 基础 / 重型炮的锁定目标
var _target_pos := Vector2.INF    # 迫击炮的瞄准落点
var _aim := -PI * 0.5
var _recoil := 0.0


func _ready() -> void:
	kind = GameConfig.Build.CANNON
	tint = GameConfig.C_CANNON
	max_hp = 300.0
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
#  满级分支：重型炮 / 迫击炮
# ============================================================
func can_branch() -> bool:
	## 3 级且尚未分支时可选路线
	return level >= max_level and kind == GameConfig.Build.CANNON


func branch_options() -> Array:
	return [GameConfig.Build.CANNON_HEAVY, GameConfig.Build.CANNON_MORTAR]


func branch_cost() -> float:
	return GameConfig.CANNON_BRANCH_COST


func branch_to(new_kind: int) -> bool:
	## 二选一定型：改 kind / 配色 / 数值并封顶，之后不可再升级
	if not can_branch():
		return false
	if not branch_options().has(new_kind):
		return false
	if not GameState.try_spend(GameConfig.CANNON_BRANCH_COST):
		return false

	invested += GameConfig.CANNON_BRANCH_COST
	max_level = level
	_apply_branch(new_kind)
	_target = null
	_target_pos = Vector2.INF
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
	splash_radius = 0.0
	match new_kind:
		GameConfig.Build.CANNON_HEAVY:
			tint = GameConfig.C_CANNON_HEAVY
			damage = GameConfig.HEAVY_DAMAGE
			fire_interval = GameConfig.HEAVY_INTERVAL
		GameConfig.Build.CANNON_MORTAR:
			tint = GameConfig.C_CANNON_MORTAR
			damage = GameConfig.MORTAR_DAMAGE
			fire_interval = GameConfig.MORTAR_INTERVAL
			range_cells = GameConfig.MORTAR_RANGE
			splash_radius = GameConfig.MORTAR_SPLASH


func can_retrofit() -> bool:
	## 已定型且场上存在改造车间时可改为另一分支
	return kind != GameConfig.Build.CANNON and level >= max_level \
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
	_target = null
	_target_pos = Vector2.INF
	_up_pulse = 1.0
	_recoil = 6.0
	queue_redraw()
	return true


func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	_scan_cd -= delta
	_recoil = maxf(0.0, _recoil - delta * 60.0)

	# 索敌节流：每 0.12 秒扫一次
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		if splash_radius > 0.0:
			_target_pos = _acquire_cluster_point()
		elif kind == GameConfig.Build.CANNON_HEAVY:
			_target = _acquire_tankiest()
		else:
			_target = _acquire()

	if splash_radius > 0.0:
		# 迫击炮：朝落点方向转动炮管，CD 好了就朝落点开火
		if _target_pos != Vector2.INF:
			_aim = lerp_angle(_aim, global_position.angle_to_point(_target_pos),
					clampf(delta * 10.0, 0.0, 1.0))
			if _cd <= 0.0 and _in_range(_target_pos):
				_cd = fire_interval
				_shoot_pos(_target_pos)
	elif _target != null and is_instance_valid(_target):
		_aim = lerp_angle(_aim, global_position.angle_to_point(_target.global_position),
				clampf(delta * 14.0, 0.0, 1.0))
		if _cd <= 0.0 and _in_range(_target.global_position):
			_cd = fire_interval
			_shoot(_target)

	queue_redraw()


func _range_px() -> float:
	return range_cells * GameConfig.CELL


func _in_range(p: Vector2) -> bool:
	return global_position.distance_squared_to(p) <= _range_px() * _range_px()


## 基础形态：射程内最近的敌人
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


## 重型炮：射程内血量上限最高的敌人（Boss / 重甲优先）
func _acquire_tankiest() -> Node2D:
	var best: Node2D = null
	var best_hp := -1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		if not _in_range(e.global_position):
			continue
		if e.max_hp > best_hp:
			best_hp = e.max_hp
			best = e
	return best


## 迫击炮：溅射半径内敌人最多的落点（在射程内的敌人里选“炮火覆盖价值”最高的一点）
func _acquire_cluster_point() -> Vector2:
	var list := get_tree().get_nodes_in_group("enemies")
	var best_pos := Vector2.INF
	var best_n := 0
	var r2 := splash_radius * splash_radius
	for e in list:
		if e.dead or not _in_range(e.global_position):
			continue
		var n := 0
		for f in list:
			if f.dead:
				continue
			if e.global_position.distance_squared_to(f.global_position) <= r2:
				n += 1
		if n > best_n:
			best_n = n
			best_pos = e.global_position
	return best_pos


func _shoot(e: Node2D) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position + Vector2(cos(_aim), sin(_aim)) * 14.0
	p.setup(e, damage * GameState.building_dmg_mul, proj_speed, tint)
	layer.add_child(p)
	_recoil = 5.0


func _shoot_pos(pos: Vector2) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position + Vector2(cos(_aim), sin(_aim)) * 14.0
	p.setup_splash(pos, damage * GameState.building_dmg_mul, proj_speed, tint, splash_radius)
	layer.add_child(p)
	_recoil = 5.0


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 4.0

	# 底座平台
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.24, 0.15, 0.10), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.25), false, 2.0)
	draw_circle(Vector2.ZERO, half * 0.62, Color(col.r, col.g, col.b, 0.16))

	# 炮管（朝目标方向，射击时后坐；分支外观：重型长管 + 制退器 / 迫击炮短粗管 + 炮口环）
	var dir := Vector2(cos(_aim), sin(_aim))
	var perp := Vector2(-dir.y, dir.x)
	if kind == GameConfig.Build.CANNON_MORTAR:
		var tip := dir * (9.0 - _recoil)
		draw_colored_polygon(PackedVector2Array([
			tip + perp * 5.5, tip - perp * 5.5,
			-perp * 5.5 - dir * 5.0, perp * 5.5 - dir * 5.0,
		]), col)
		draw_circle(tip, 4.0, col.darkened(0.35))
	elif kind == GameConfig.Build.CANNON_HEAVY:
		var tip := dir * (17.0 - _recoil)
		draw_colored_polygon(PackedVector2Array([
			tip + perp * 4.0, tip - perp * 4.0,
			-perp * 5.0 - dir * 5.0, perp * 5.0 - dir * 5.0,
		]), col)
		var muzzle := tip - dir * 3.0
		draw_line(muzzle + perp * 6.0, muzzle - perp * 6.0, col.darkened(0.3), 3.0)
	else:
		var tip := dir * (13.0 - _recoil)
		draw_colored_polygon(PackedVector2Array([
			tip + perp * 4.5, tip - perp * 4.5,
			-perp * 5.5 - dir * 5.0, perp * 5.5 - dir * 5.0,
		]), col)
	draw_circle(Vector2.ZERO, 5.0, col.lightened(0.45))

	_draw_hp_bar(24.0, -half - 8.0)
	super._draw()
