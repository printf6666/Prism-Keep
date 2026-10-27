class_name Projectile
extends Node2D
## 弹丸：追踪目标点飞行，命中即结算伤害

var target: Node2D = null
var damage := 10.0
var speed := 640.0
var tint := Color.WHITE


func _ready() -> void:
	z_index = 5


func setup(t: Node2D, dmg: float, spd: float, col: Color) -> void:
	target = t
	damage = dmg
	speed = spd
	tint = col


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return

	var to: Vector2 = target.global_position - global_position
	var dist := to.length()
	var step := speed * delta

	if dist <= step + 4.0:
		target.take_damage(damage)
		queue_free()
		return

	global_position += to / dist * step


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, tint.lightened(0.35))
	draw_circle(Vector2.ZERO, 1.4, Color(1, 1, 1, 0.9))
