extends Building
## 箭塔：自动索敌，向射程内最近的敌人发射弹丸

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var range_cells := 5.0
var damage := 14.0
var fire_interval := 0.5
var proj_speed := 640.0

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
	_cd = randf() * 0.2
	_scan_cd = randf() * 0.1


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
		if _cd <= 0.0 and _in_range(_target):
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
	p.setup(e, damage, proj_speed, tint)
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
