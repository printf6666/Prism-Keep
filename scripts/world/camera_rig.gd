extends Camera2D
## 跟随角色的上帝视角相机：视角永远跟着角色走，滚轮缩放，F 立即归位

const MIN_ZOOM := 0.25
const MAX_ZOOM := 2.00
const FOLLOW_SPEED := 10.0

var _target: Node2D


func _ready() -> void:
	zoom = Vector2(0.70, 0.70)
	_target = get_tree().get_first_node_in_group("player")
	if _target != null:
		position = _target.global_position
	else:
		position = GameConfig.base_center()
	_clamp_position()
	make_current()


func _process(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		var k := 1.0 - exp(-FOLLOW_SPEED * delta)
		position = position.lerp(_target.global_position, k)
	_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.12)

	elif event is InputEventKey:
		var mk := event as InputEventKey
		if mk.pressed and not mk.echo and mk.keycode == KEY_F:
			if _target != null and is_instance_valid(_target):
				position = _target.global_position
				_clamp_position()


func _zoom_at(factor: float) -> void:
	var vp_size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var before: Vector2 = (mouse - vp_size * 0.5) / zoom + position

	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)

	var after: Vector2 = (mouse - vp_size * 0.5) / zoom + position
	position += before - after
	_clamp_position()


func _clamp_position() -> void:
	var world := GameConfig.world_size()
	var half := get_viewport_rect().size * 0.5 / zoom

	if half.x * 2.0 < world.x:
		position.x = clampf(position.x, half.x, world.x - half.x)
	else:
		position.x = world.x * 0.5

	if half.y * 2.0 < world.y:
		position.y = clampf(position.y, half.y, world.y - half.y)
	else:
		position.y = world.y * 0.5
