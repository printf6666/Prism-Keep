class_name Projectile
extends Node2D
## 弹丸：追踪目标点飞行，命中即结算伤害；带 freeze 参数的冰晶弹命中后冻结目标

var target: Node2D = null
var damage := 10.0
var speed := 640.0
var tint := Color.WHITE
var freeze := 0.0

var _dir := Vector2.RIGHT


func _ready() -> void:
	z_index = 5


func setup(t: Node2D, dmg: float, spd: float, col: Color, freeze_dur := 0.0) -> void:
	target = t
	damage = dmg
	speed = spd
	tint = col
	freeze = freeze_dur


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return

	var to: Vector2 = target.global_position - global_position
	var dist := to.length()
	var step := speed * delta

	if dist <= step + 4.0:
		target.take_damage(damage)
		if freeze > 0.0 and target.has_method("apply_freeze"):
			target.apply_freeze(freeze)
		queue_free()
		return

	_dir = to / dist
	global_position += _dir * step


func _draw() -> void:
	if freeze > 0.0:
		# 冰晶弹：沿飞行方向的菱形碎片 + 光晕
		var perp := Vector2(-_dir.y, _dir.x)
		draw_circle(Vector2.ZERO, 4.5, Color(tint.r, tint.g, tint.b, 0.25))
		draw_colored_polygon(PackedVector2Array([
			_dir * 6.5, perp * 2.6, -_dir * 6.5, -perp * 2.6,
		]), tint.lightened(0.35))
		draw_circle(Vector2.ZERO, 1.6, Color(1, 1, 1, 0.95))
	else:
		draw_circle(Vector2.ZERO, 3.0, tint.lightened(0.35))
		draw_circle(Vector2.ZERO, 1.4, Color(1, 1, 1, 0.9))
