extends Building
## 寒冰塔：向射程内最近的敌人发射冰晶弹，命中后将其冰冻（无法移动与攻击）

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var range_cells := 4.0
var damage := 10.0
var fire_interval := 1.1
var proj_speed := 560.0
var freeze_time := 1.0

var _cd := 0.0
var _scan_cd := 0.0
var _target: Node2D = null
var _spin := 0.0
var _pulse := 0.0


func _ready() -> void:
	kind = GameConfig.Build.FROST
	tint = GameConfig.C_FROST
	max_hp = 220.0
	hp = max_hp
	max_level = GameConfig.MAX_LEVEL
	_cd = randf() * 0.3
	_scan_cd = randf() * 0.1
	_spin = randf() * TAU


func _on_upgraded() -> void:
	super._on_upgraded()
	damage *= 1.5
	freeze_time += 0.25


func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	_scan_cd -= delta
	_spin += delta * 1.4
	_pulse = maxf(0.0, _pulse - delta * 2.5)

	# 索敌节流：每 0.12 秒扫一次，避免每帧全表遍历
	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target = _acquire()

	if _target != null and is_instance_valid(_target) \
			and _cd <= 0.0 and _in_range(_target):
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
	p.global_position = global_position
	p.setup(e, damage, proj_speed, tint, freeze_time)
	layer.add_child(p)
	_pulse = 1.0


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 4.0

	# 底座平台
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.10, 0.19, 0.26), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.25), false, 2.0)
	draw_circle(Vector2.ZERO, half * 0.62, Color(col.r, col.g, col.b, 0.14))

	# 冰晶：缓慢旋转的三轴雪花，发射时亮起
	var r := 9.0 + sin(_spin * 2.0) * 1.2 + _pulse * 3.0
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var d := Vector2(cos(a), sin(a))
		draw_line(-d * r, d * r, col, 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 3.5 + _pulse * 2.0, col.lightened(0.5))

	# 发射脉冲
	if _pulse > 0.0:
		draw_arc(Vector2.ZERO, 10.0 + (1.0 - _pulse) * 10.0, 0.0, TAU, 24,
				Color(col.r, col.g, col.b, _pulse * 0.7), 2.0, true)

	_draw_hp_bar(24.0, -half - 8.0)
	super._draw()
