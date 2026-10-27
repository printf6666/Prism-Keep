extends Node2D
## 网格地面：只绘制视口可见的那部分格子，100x100 也不会掉帧

func _ready() -> void:
	z_index = 0
	Board.layout_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	# 相机移动后可见区域变化，重绘
	queue_redraw()


func _draw() -> void:
	var map := Rect2(Vector2.ZERO, GameConfig.world_size())
	draw_rect(map, GameConfig.C_BG, true)

	var view := _view_rect().intersection(map)
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return

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
	var gold := GameConfig.C_MINE
	var rock := Color(0.30, 0.27, 0.22)
	for oc in Board.ore_cells():
		var cc := Board.cell_to_world(oc)
		draw_rect(Rect2(cc - Vector2(half, half), Vector2(cell, cell)),
				Color(gold.r, gold.g, gold.b, 0.06), true)
		draw_circle(cc + Vector2(-4.0, -3.0), 6.5, rock)
		draw_circle(cc + Vector2(5.0, 2.0), 5.5, rock.lightened(0.10))
		draw_circle(cc + Vector2(0.5, 4.5), 4.5, rock.darkened(0.10))
		draw_circle(cc + Vector2(-3.0, -5.0), 2.0, gold.darkened(0.20))
		draw_circle(cc + Vector2(4.5, 0.5), 1.7, gold.darkened(0.05))
		draw_circle(cc + Vector2(-1.0, 4.0), 1.5, gold.darkened(0.35))

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
