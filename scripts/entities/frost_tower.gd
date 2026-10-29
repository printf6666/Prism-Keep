extends Building
## 寒冰塔：向射程内最近的敌人发射冰晶弹，命中后将其冰冻（无法移动与攻击）
## 满级分支二选一：
##   · 冰暴塔：冰暴弹落地爆炸，3×3 范围内敌人受伤害并被减速
##   · 不朽塔：激光锁定单个敌人持续攻击，目标被冻结在原地，伤害随锁定时间提升，目标丢失后重置

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var range_cells := 4.0
var damage := 10.0
var fire_interval := 1.1
var proj_speed := 560.0
var freeze_time := 1.0
var splash_radius := 0.0   # >0 = 冰暴塔（落点爆炸 + 减速）

var _base_damage := 0.0    # 1 级基础值（改造换分支时按等级重新成长）
var _base_range := 0.0
var _base_interval := 0.0
var _base_freeze := 0.0

var _cd := 0.0
var _scan_cd := 0.0
var _target: Node2D = null
var _spin := 0.0
var _pulse := 0.0
var _lock_time := 0.0      # 激光连续锁定时长（伤害随其提升，目标丢失即重置）


func _ready() -> void:
	kind = GameConfig.Build.FROST
	tint = GameConfig.C_FROST
	max_hp = 220.0
	hp = max_hp
	max_level = GameConfig.MAX_LEVEL
	_base_damage = damage
	_base_range = range_cells
	_base_interval = fire_interval
	_base_freeze = freeze_time
	_cd = randf() * 0.3
	_scan_cd = randf() * 0.1
	_spin = randf() * TAU


func _on_upgraded() -> void:
	super._on_upgraded()
	damage *= 1.5
	freeze_time += 0.25
	range_cells += 1.0


# ============================================================
#  满级分支：冰暴塔 / 不朽塔
# ============================================================
func can_branch() -> bool:
	## 3 级且尚未分支时可选路线
	return level >= max_level and kind == GameConfig.Build.FROST


func branch_options() -> Array:
	return [GameConfig.Build.FROST_STORM, GameConfig.Build.FROST_BEAM]


func branch_cost() -> float:
	return GameConfig.FROST_BRANCH_COST


func branch_to(new_kind: int) -> bool:
	## 二选一定型：改 kind / 配色 / 数值并封顶，之后不可再升级
	if not can_branch():
		return false
	if not branch_options().has(new_kind):
		return false
	if not GameState.try_spend(GameConfig.FROST_BRANCH_COST):
		return false

	invested += GameConfig.FROST_BRANCH_COST
	max_level = level
	_apply_branch(new_kind)
	_target = null
	_lock_time = 0.0
	_up_pulse = 1.0
	_pulse = 1.0
	queue_redraw()
	return true


func _apply_branch(new_kind: int) -> void:
	## 按分支重置数值：先回到基础值按等级成长，再应用分支特性（改造换分支也走这里）
	kind = new_kind
	damage = _base_damage * pow(1.5, float(level - 1))
	range_cells = _base_range + float(level - 1)
	fire_interval = _base_interval
	freeze_time = _base_freeze + 0.25 * float(level - 1)
	splash_radius = 0.0
	match new_kind:
		GameConfig.Build.FROST_STORM:
			tint = GameConfig.C_FROST_STORM
			damage = GameConfig.STORM_DAMAGE
			fire_interval = GameConfig.STORM_INTERVAL
			range_cells = GameConfig.STORM_RANGE
			splash_radius = GameConfig.STORM_SPLASH
		GameConfig.Build.FROST_BEAM:
			tint = GameConfig.C_FROST_BEAM
			range_cells = GameConfig.BEAM_RANGE


func can_retrofit() -> bool:
	## 已定型且场上存在改造车间时可改为另一分支
	return kind != GameConfig.Build.FROST and level >= max_level \
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
	_lock_time = 0.0
	_up_pulse = 1.0
	_pulse = 1.0
	queue_redraw()
	return true


func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	_scan_cd -= delta
	_spin += delta * 1.4
	_pulse = maxf(0.0, _pulse - delta * 2.5)

	if splash_radius > 0.0:
		_storm_process(delta)
	elif kind == GameConfig.Build.FROST_BEAM:
		_beam_process(delta)
	else:
		_base_process(delta)

	queue_redraw()


## 基础形态：冰晶弹单体冰冻
func _base_process(_delta: float) -> void:
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target = _acquire()

	if _target != null and is_instance_valid(_target) \
			and _cd <= 0.0 and _in_range(_target.global_position):
		_cd = fire_interval
		_shoot(_target)


## 冰暴塔：冰暴弹落点爆炸，3×3 内伤害 + 减速
func _storm_process(_delta: float) -> void:
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target = _acquire()

	if _target != null and is_instance_valid(_target) \
			and _cd <= 0.0 and _in_range(_target.global_position):
		_cd = fire_interval
		_shoot_splash(_target.global_position)


## 不朽塔：激光锁定单个敌人，冻结原地，伤害随锁定时间提升
func _beam_process(delta: float) -> void:
	# 目标丢失（死亡 / 走出射程）→ 伤害回归原位，重新索敌
	if _target == null or not is_instance_valid(_target) or _target.dead \
			or not _in_range(_target.global_position):
		_lock_time = 0.0
		_target = _acquire()
	if _target == null or not is_instance_valid(_target):
		return

	_lock_time += delta
	_target.apply_freeze(0.15)   # 持续刷新冻结，把目标按在原地
	var cap := _ramp_cap(_target)
	var mul := 1.0 + minf(_lock_time * GameConfig.BEAM_RAMP, cap - 1.0)
	_target.take_damage(GameConfig.BEAM_DPS * GameState.building_dmg_mul * mul * delta)


## 激光增伤上限：Boss 3 倍 / 精英怪（重甲）5 倍 / 其余敌人无上限
func _ramp_cap(e) -> float:
	match String(e.type):
		"boss":
			return GameConfig.BEAM_RAMP_CAP_BOSS
		"tank":
			return GameConfig.BEAM_RAMP_CAP_ELITE
	return INF


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


func _shoot(e: Node2D) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position
	p.setup(e, damage * GameState.building_dmg_mul, proj_speed, tint, freeze_time)
	layer.add_child(p)
	_pulse = 1.0


func _shoot_splash(pos: Vector2) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position
	p.setup_splash(pos, damage * GameState.building_dmg_mul, proj_speed, tint, splash_radius,
			GameConfig.STORM_SLOW_TIME, GameConfig.STORM_SLOW_FACTOR)
	layer.add_child(p)
	_pulse = 1.0


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 4.0

	# 底座平台
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.10, 0.19, 0.26), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.25), false, 2.0)
	draw_circle(Vector2.ZERO, half * 0.62, Color(col.r, col.g, col.b, 0.14))

	# 冰晶：缓慢旋转的多轴雪花，发射时亮起；分支外观区分轴数
	var axes := 6 if kind == GameConfig.Build.FROST_STORM else 3
	var r := (11.0 if splash_radius > 0.0 else 9.0) + sin(_spin * 2.0) * 1.2 + _pulse * 3.0
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
	for i in axes:
		var a := TAU * float(i) / float(axes)
		var d := Vector2(cos(a), sin(a))
		draw_line(-d * r, d * r, col, 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 3.5 + _pulse * 2.0, col.lightened(0.5))

	# 激光：锁定目标时画出主光束 + 白色内芯 + 命中点光斑
	if kind == GameConfig.Build.FROST_BEAM and _target != null and is_instance_valid(_target):
		var tip := to_local(_target.global_position)
		var beam := col.lightened(0.25)
		draw_line(Vector2.ZERO, tip, Color(beam.r, beam.g, beam.b, 0.45), 4.0, true)
		draw_line(Vector2.ZERO, tip, Color(1, 1, 1, 0.9), 1.5, true)
		draw_arc(tip, 5.0 + sin(_spin * 4.0) * 1.5, 0.0, TAU, 16, beam, 2.0, true)

	# 发射脉冲
	if _pulse > 0.0:
		draw_arc(Vector2.ZERO, 10.0 + (1.0 - _pulse) * 10.0, 0.0, TAU, 24,
				Color(col.r, col.g, col.b, _pulse * 0.7), 2.0, true)

	_draw_hp_bar(24.0, -half - 8.0)
	super._draw()
