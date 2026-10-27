extends Node2D
## 玩家角色（占位符，纯几何体拼的）
## - WASD 自由移动，视角跟着角色走，移动方向即面朝方向
## - 目前没有任何攻击手段，只是一个“人在这儿”的锚点

var _face := -PI * 0.5
var _bob := 0.0
var _moving := false


func _ready() -> void:
	z_index = 7
	# 站在大本营正下方，避免和基地图形叠在一起看不见
	position = GameConfig.base_center() + Vector2(0.0, GameConfig.CELL * 2.5)


func _process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_moving = dir.length_squared() > 0.0001

	if _moving:
		_face = lerp_angle(_face, dir.angle(), clampf(delta * 16.0, 0.0, 1.0))
		var step := dir * GameConfig.PLAYER_SPEED * delta
		var p := position
		# 分轴移动：撞墙时可以贴着滑
		if _walkable(p + Vector2(step.x, 0.0)):
			p.x += step.x
		if _walkable(p + Vector2(0.0, step.y)):
			p.y += step.y
		position = p
		_bob += delta * 12.0
	else:
		_bob = lerp(_bob, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	queue_redraw()


func _walkable(p: Vector2) -> bool:
	var ws := GameConfig.world_size()
	var r := GameConfig.PLAYER_RADIUS
	if p.x < r or p.y < r or p.x > ws.x - r or p.y > ws.y - r:
		return false
	return Board.get_building(Board.cell_of(p)) == null


## 角色面前一格：朝向主导轴方向的相邻格，F / G 键互动的目标
## （斜向移动时取 x / y 分量较大的一侧，保证结果永远是正交相邻格）
func front_cell() -> Vector2i:
	var dir := Vector2(cos(_face), sin(_face))
	var off := Vector2i.ZERO
	if absf(dir.x) >= absf(dir.y):
		off.x = 1 if dir.x >= 0.0 else -1
	else:
		off.y = 1 if dir.y >= 0.0 else -1
	return Board.cell_of(global_position) + off


func _draw() -> void:
	var r := GameConfig.PLAYER_RADIUS
	var accent := GameConfig.C_BASE
	var body := Color(0.92, 0.95, 1.00)
	var dir := Vector2(cos(_face), sin(_face))
	var perp := Vector2(-dir.y, dir.x)

	# 影子
	draw_circle(Vector2(0.0, 5.0), r * 0.95, Color(0, 0, 0, 0.30))

	# 双脚（走路时前后摆，露在身体下沿）
	var sw: float = sin(_bob) * 3.5 if _moving else 0.0
	draw_circle(Vector2(-4.5, 7.0 + sw), 3.2, body.darkened(0.45))
	draw_circle(Vector2(4.5, 7.0 - sw), 3.2, body.darkened(0.45))

	# 身体
	draw_circle(Vector2.ZERO, r, body)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, accent.darkened(0.25), 2.0, true)

	# 朝向楔形（画在身体之上，指向当前移动方向）
	draw_colored_polygon(PackedVector2Array([
		dir * (r + 6.0),
		dir * (r * 0.30) + perp * 5.0,
		dir * (r * 0.30) - perp * 5.0,
	]), accent)

	# 头（顶视：一个小圆）
	draw_circle(Vector2.ZERO, r * 0.42, accent.lightened(0.35))
	draw_circle(Vector2.ZERO, r * 0.20, Color(1, 1, 1))
