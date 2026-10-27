class_name Building
extends Node2D
## 所有建筑的基类：占格、血量、受击闪白、被摧毁时的爆炸特效

const FX_SCENE := preload("res://scenes/fx/burst_fx.tscn")

var cell := Vector2i.ZERO
var kind := 0
var is_wall := false
var max_hp := 100.0
var hp := 100.0
var tint := Color.WHITE

var _flash := 0.0


func place(c: Vector2i) -> void:
	cell = c
	position = Board.cell_to_world(c)
	Board.register(self, c)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		_destroy()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.5)
		queue_redraw()


func _destroy() -> void:
	Board.unregister(cell)
	_spawn_fx()
	queue_free()


func _spawn_fx() -> void:
	var fx := FX_SCENE.instantiate() as BurstFx
	fx.position = position
	fx.tint = tint
	fx.max_radius = 26.0
	get_parent().add_child(fx)


## 子类绘制时统一取“受击提亮”的颜色
func _body_color(base: Color) -> Color:
	if _flash > 0.0:
		return base.lerp(Color(1, 1, 1), _flash * 0.75)
	return base


## 血条：仅在掉血后显示
func _draw_hp_bar(width: float, y: float) -> void:
	if hp >= max_hp:
		return
	var p := clampf(hp / max_hp, 0.0, 1.0)
	var h := 3.0
	draw_rect(Rect2(-width * 0.5, y, width, h), Color(0, 0, 0, 0.55), true)
	var c: Color = GameConfig.C_OK
	if p <= 0.25:
		c = GameConfig.C_BAD
	elif p <= 0.5:
		c = Color(1.0, 0.78, 0.28)
	draw_rect(Rect2(-width * 0.5, y, width * p, h), c, true)
