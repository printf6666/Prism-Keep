extends Camera2D
## 跟随角色的上帝视角相机：视角只跟着角色移动，缩放固定不可调

const FOLLOW_SPEED := 10.0
const FIXED_ZOOM := 0.85

var _target: Node2D


func _ready() -> void:
	zoom = Vector2(FIXED_ZOOM, FIXED_ZOOM)
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
