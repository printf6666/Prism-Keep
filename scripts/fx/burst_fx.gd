class_name BurstFx
extends Node2D
## 一次性爆散特效：扩散圆环 + 渐隐实心点，播完自动销毁

var tint := Color.WHITE
var max_radius := 20.0
var duration := 0.42

var _t := 0.0


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var r := max_radius * (0.3 + p * 1.0)
	var a := 1.0 - p
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, a * 0.85),
			2.5 * a + 0.5, true)
	draw_circle(Vector2.ZERO, max_radius * 0.3 * (1.0 - p), Color(tint.r, tint.g, tint.b, a * 0.5))
