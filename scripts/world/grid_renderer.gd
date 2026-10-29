extends Node2D
## 网格地面：只绘制视口可见的那部分格子，100x100 也不会掉帧
## 另含末日废土的地面基调：大面积明暗色斑（每局随机生成一次）

var _patches: Array = []   # {pos, r, col} 废土色斑


func _ready() -> void:
	z_index = 0
	Board.layout_changed.connect(queue_redraw)
	_gen_patches()


## 废土色斑：暗橄榄 / 枯棕的大块明暗变化，让地面不再是单调纯色
func _gen_patches() -> void:
	var ws := GameConfig.world_size()
	for i in 26:
		var cols := [
			Color(0.075, 0.070, 0.055),
			Color(0.048, 0.056, 0.048),
			Color(0.080, 0.066, 0.050),
			Color(0.058, 0.062, 0.045),
		]
		_patches.append({
			"pos": Vector2(randf_range(0.0, ws.x), randf_range(0.0, ws.y)),
			"r": randf_range(90.0, 220.0),
			"col": cols[i % cols.size()],
		})


func _process(_delta: float) -> void:
	# 相机移动后可见区域变化，重绘
	queue_redraw()


func _draw() -> void:
	var map := Rect2(Vector2.ZERO, GameConfig.world_size())
	draw_rect(map, GameConfig.C_BG, true)

	var view := _view_rect().intersection(map)
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return

	# 废土色斑（只画视口附近的）
	for p in _patches:
		if p["pos"].x + p["r"] < view.position.x or p["pos"].x - p["r"] > view.end.x \
				or p["pos"].y + p["r"] < view.position.y or p["pos"].y - p["r"] > view.end.y:
			continue
		draw_circle(p["pos"], p["r"], p["col"])

	var cell := GameConfig.CELL
	var half := cell * 0.5
	var x0 := maxi(0, int(floor(view.position.x / cell)))
	var x1 := mini(GameConfig.GRID_W, int(ceil(view.end.x / cell)))
	var y0 := maxi(0, int(floor(view.position.y / cell)))
	var y1 := mini(GameConfig.GRID_H, int(ceil(view.end.y / cell)))

	var top := Vector2(0.0, view.position.y)
	var bottom := Vector2(0.0, view.end.y)
	for x in range(x0, x1 + 1):
		var px := float(x) * cell
		var col: Color = GameConfig.C_GRID_MAJOR if x % 10 == 0 else GameConfig.C_GRID_MINOR
		draw_line(Vector2(px, top.y), Vector2(px, bottom.y), col, 1.0)

	var left := Vector2(view.position.x, 0.0)
	var right := Vector2(view.end.x, 0.0)
	for y in range(y0, y1 + 1):
		var py := float(y) * cell
		var col: Color = GameConfig.C_GRID_MAJOR if y % 10 == 0 else GameConfig.C_GRID_MINOR
		draw_line(Vector2(left.x, py), Vector2(right.x, py), col, 1.0)

	# 矿山格：淡金底 + 岩体矿粒（地形标记，不阻挡通行，金矿的唯一落点）
	# 大金矿：更大更亮的岩体 + 金色光环，产金翻倍
	var gold := GameConfig.C_MINE
	var rock := Color(0.30, 0.27, 0.22)
	for oc in Board.ore_cells():
		var cc := Board.cell_to_world(oc)
		var rich := Board.is_rich_ore(oc)
		var k := 1.35 if rich else 1.0
		draw_rect(Rect2(cc - Vector2(half, half), Vector2(cell, cell)),
				Color(gold.r, gold.g, gold.b, 0.12 if rich else 0.06), true)
		draw_circle(cc + Vector2(-4.0, -3.0) * k, 6.5 * k, rock)
		draw_circle(cc + Vector2(5.0, 2.0) * k, 5.5 * k, rock.lightened(0.10))
		draw_circle(cc + Vector2(0.5, 4.5) * k, 4.5 * k, rock.darkened(0.10))
		draw_circle(cc + Vector2(-3.0, -5.0) * k, 2.0 * k, gold.darkened(0.20))
		draw_circle(cc + Vector2(4.5, 0.5) * k, 1.7 * k, gold)
		draw_circle(cc + Vector2(-1.0, 4.0) * k, 1.5 * k, gold.darkened(0.35))
		if rich:
			draw_arc(cc, 14.5, 0.0, TAU, 20, Color(gold.r, gold.g, gold.b, 0.65), 1.5, true)

	# 地图外框
	draw_rect(map, GameConfig.C_MAP_EDGE, false, 3.0)


func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(Vector2.ZERO, GameConfig.world_size())
	var inv := vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * vp.get_visible_rect().size
	return Rect2(a, b - a)
