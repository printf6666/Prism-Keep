extends Control
## 小地图：整张地图的缩略图（HUD 右上角），纯代码绘制
## 实时显示大本营、矿山、建筑、敌人、角色与当前视野框

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	size = Vector2(160, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()   # 内容随帧变化（敌人 / 视野框），整帧重绘代价可忽略


func _draw() -> void:
	var s := size.x / float(GameConfig.GRID_W)   # 每格像素

	# 底色与外框
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.88), true)
	draw_rect(Rect2(Vector2.ZERO, size), GameConfig.C_MAP_EDGE, false, 1.5)

	# 大本营（2×2 蓝块）
	var base_pos := Vector2(GameConfig.BASE_CELL) * s
	draw_rect(Rect2(base_pos, Vector2(GameConfig.BASE_SIZE, GameConfig.BASE_SIZE) * s),
			GameConfig.C_BASE, true)

	# 矿山（金点）
	for oc in Board.ore_cells():
		draw_circle((Vector2(oc) + Vector2(0.5, 0.5)) * s, 1.1,
				Color(GameConfig.C_MINE.r, GameConfig.C_MINE.g, GameConfig.C_MINE.b, 0.7))

	# 建筑（按各自配色，多格建筑只画一个点）
	var seen := {}
	for i in Board.buildings:
		var b = Board.buildings[i]
		if seen.has(b) or not is_instance_valid(b):
			continue
		seen[b] = true
		draw_circle(b.global_position * (s / GameConfig.CELL), 1.8, b.tint)

	# 敌人（红系小点）
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var p: Vector2 = e.global_position / GameConfig.CELL * s
		draw_circle(p, clampf(e.radius * 0.14, 1.2, 2.2), e.color.lightened(0.2))

	# 角色（白点 + 蓝色光环）
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl):
		var pp: Vector2 = pl.global_position / GameConfig.CELL * s
		draw_circle(pp, 2.4, Color(1, 1, 1))
		draw_arc(pp, 4.2, 0.0, TAU, 12, GameConfig.C_BASE, 1.2, true)

	# 视野框（当前相机可见的世界矩形）
	var vp := get_viewport()
	if vp != null:
		var inv := vp.get_canvas_transform().affine_inverse()
		var a: Vector2 = inv * Vector2.ZERO
		var b2: Vector2 = inv * vp.get_visible_rect().size
		var rect := Rect2(a * (s / GameConfig.CELL), (b2 - a) * (s / GameConfig.CELL))
		draw_rect(rect, Color(1, 1, 1, 0.30), false, 1.0)
