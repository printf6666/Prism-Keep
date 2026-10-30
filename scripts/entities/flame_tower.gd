extends Building
## 喷火器：45° 扇形火舌，点燃敌人（每秒烧 1% 最大生命值，持续 10 秒）
## 满级分支二选一：
##   · 烈炎塔：攻击方式不变，射程大幅扩大
##   · 熔岩塔：向敌人密集处投掷岩浆，岩浆内灼烧翻倍（2%/秒起）并蔓延约 3 格

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var range_cells := 3.0
var damage := 8.0
var fire_interval := 0.8

var _base_damage := 0.0   # 1 级基础值（改造换分支时按等级重新成长）
var _base_range := 0.0
var _base_interval := 0.0

var _cd := 0.0
var _scan_cd := 0.0
var _target: Node2D = null        # 扇形模式的瞄准目标
var _target_pos := Vector2.INF    # 熔岩塔的瞄准落点
var _aim := -PI * 0.5
var _breath := 0.0                # 喷火视觉强度


func _ready() -> void:
	kind = GameConfig.Build.FLAME
	tint = GameConfig.C_FLAME
	max_hp = 240.0
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
	_breath = 1.0


# ============================================================
#  满级分支：烈炎塔 / 熔岩塔
# ============================================================
func can_branch() -> bool:
	return level >= max_level and kind == GameConfig.Build.FLAME


func branch_options() -> Array:
	return [GameConfig.Build.FLAME_BLAZE, GameConfig.Build.MAGMA]


func branch_cost() -> float:
	return GameConfig.FLAME_BRANCH_COST


func branch_to(new_kind: int) -> bool:
	if not can_branch():
		return false
	if not branch_options().has(new_kind):
		return false
	if not GameState.try_spend(GameConfig.FLAME_BRANCH_COST):
		return false

	invested += GameConfig.FLAME_BRANCH_COST
	max_level = level
	_apply_branch(new_kind)
	_target = null
	_target_pos = Vector2.INF
	_up_pulse = 1.0
	_breath = 1.0
	queue_redraw()
	return true


func _apply_branch(new_kind: int) -> void:
	kind = new_kind
	damage = _base_damage * pow(1.5, float(level - 1))
	range_cells = _base_range + float(level - 1)
	fire_interval = _base_interval
	match new_kind:
		GameConfig.Build.FLAME_BLAZE:
			tint = GameConfig.C_FLAME_BLAZE
			range_cells = GameConfig.BLAZE_RANGE
		GameConfig.Build.MAGMA:
			tint = GameConfig.C_MAGMA
			fire_interval = GameConfig.MAGMA_INTERVAL
			range_cells = GameConfig.MAGMA_RANGE


func can_retrofit() -> bool:
	return kind != GameConfig.Build.FLAME and level >= max_level \
			and Board.has_kind(GameConfig.Build.RETOOL)


func retrofit_options() -> Array:
	var opts: Array = []
	for k in branch_options():
		if k != kind:
			opts.append(k)
	return opts


func retrofit_to(new_kind: int) -> bool:
	if not can_retrofit() or not retrofit_options().has(new_kind):
		return false
	if not GameState.try_spend(retrofit_cost()):
		return false
	invested += retrofit_cost()
	_apply_branch(new_kind)
	_target = null
	_target_pos = Vector2.INF
	_up_pulse = 1.0
	_breath = 1.0
	queue_redraw()
	return true


func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	_scan_cd -= delta
	_breath = maxf(0.0, _breath - delta * 3.0)

	if kind == GameConfig.Build.MAGMA:
		_magma_process(delta)
	else:
		_cone_process(delta)

	queue_redraw()


## 基础喷火器 / 烈炎塔：朝最近目标喷射 45° 扇形
func _cone_process(delta: float) -> void:
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target = _acquire()

	if _target != null and is_instance_valid(_target):
		_aim = lerp_angle(_aim, global_position.angle_to_point(_target.global_position),
				clampf(delta * 10.0, 0.0, 1.0))
		if not silenced() and _cd <= 0.0 and _in_range(_target.global_position):
			_cd = fire_interval
			_breath = 1.0
			_cone_attack()


## 熔岩塔：向敌人密集处投掷岩浆
func _magma_process(delta: float) -> void:
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target_pos = _acquire_cluster_point()

	if _target_pos != Vector2.INF:
		_aim = lerp_angle(_aim, global_position.angle_to_point(_target_pos),
				clampf(delta * 10.0, 0.0, 1.0))
		if not silenced() and _cd <= 0.0 and _in_range(_target_pos):
			_cd = fire_interval
			_breath = 1.0
			_shoot_pool(_target_pos)


func _range_px() -> float:
	return range_cells * GameConfig.CELL


func _in_range(p: Vector2) -> bool:
	return global_position.distance_squared_to(p) <= _range_px() * _range_px()


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


## 熔岩式索敌：溅射圈内敌人最多的落点
func _acquire_cluster_point() -> Vector2:
	var list := get_tree().get_nodes_in_group("enemies")
	var best_pos := Vector2.INF
	var best_n := 0
	var r2 := GameConfig.MAGMA_POOL_RADIUS * GameConfig.MAGMA_POOL_RADIUS
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


## 扇形攻击：45° 锥内所有敌人吃直接伤害并点燃（业火燎原觉醒：灼烧 3% 起并延长）
func _cone_attack() -> void:
	var reach := _range_px()
	var half := deg_to_rad(GameConfig.FLAME_CONE_DEG * 0.5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > reach:
			continue
		if absf(wrapf(to.angle() - _aim, -PI, PI)) > half:
			continue
		e.take_damage(damage * GameState.building_dmg_mul, self)
		var bpct: float = (0.03 if awakened else GameConfig.BURN_PCT) + GameState.burn_bonus
		e.apply_burn(bpct, GameConfig.BURN_TIME, self, 5.0 if awakened else 0.0)


func _shoot_pool(pos: Vector2) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position + Vector2(cos(_aim), sin(_aim)) * 14.0
	p.setup_pool(pos, 420.0, tint, GameConfig.MAGMA_POOL_RADIUS, GameConfig.MAGMA_POOL_TIME, self)
	layer.add_child(p)


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 4.0

	# 底座平台
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.24, 0.14, 0.08), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.25), false, 2.0)
	draw_circle(Vector2.ZERO, half * 0.62, Color(col.r, col.g, col.b, 0.16))

	var dir := Vector2(cos(_aim), sin(_aim))
	var perp := Vector2(-dir.y, dir.x)

	# 喷火：扇形火舌（呼吸强度控制透明度与长度）
	if _breath > 0.0:
		var reach := _range_px() * (0.55 + 0.25 * _breath)
		var half_ang := deg_to_rad(GameConfig.FLAME_CONE_DEG * 0.5)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 7:
			var a := _aim - half_ang + (half_ang * 2.0) * float(i) / 6.0
			pts.append(Vector2(cos(a), sin(a)) * reach)
		var flicker := 0.30 + 0.18 * sin(_breath * 20.0)
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, flicker * _breath))

	if kind == GameConfig.Build.MAGMA:
		# 熔岩塔：短粗投掷管
		var tip := dir * (9.0 - _breath * 3.0)
		draw_colored_polygon(PackedVector2Array([
			tip + perp * 5.5, tip - perp * 5.5,
			-perp * 5.5 - dir * 5.0, perp * 5.5 - dir * 5.0,
		]), col)
		draw_circle(tip, 4.0, col.darkened(0.35))
	else:
		# 喷火器 / 烈炎塔：喇叭形喷嘴
		var tip := dir * (12.0 - _breath * 3.0)
		draw_colored_polygon(PackedVector2Array([
			tip + perp * 6.5, tip - perp * 6.5,
			-perp * 3.0 - dir * 5.0, perp * 3.0 - dir * 5.0,
		]), col)
	draw_circle(Vector2.ZERO, 4.5, col.lightened(0.45))

	_draw_hp_bar(24.0, -half - 8.0)
	super._draw()
