extends Node2D
## 建造交互 + 建筑查看
##   · 选中建筑 -> 网格幽灵预览 -> 左键落子；右键/ESC 取消
##   · 未处于建造模式时，左键点已部署的建筑 = 查看它的血量 / 攻击力
##   · 悬停或选中箭塔时显示射程圈

var selected := -1          # 当前要建造的类型，-1 = 非建造模式
var hover := Vector2i(-1, -1)

var _sel: Node = null       # 当前查看中的建筑
var _buildings_root: Node2D


func _ready() -> void:
	z_index = 8
	_buildings_root = get_parent().get_node("Buildings")
	GameState.build_mode_changed.connect(_set_mode)


func _process(_delta: float) -> void:
	var c := Board.cell_of(get_global_mouse_position())
	if c != hover:
		hover = c
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if selected >= 0:
				_try_place(hover)
			else:
				_select_at(hover)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if selected >= 0:
				GameState.build_mode_changed.emit(-1)
			elif _sel != null:
				_clear_selection()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var mk := event as InputEventKey
		if not mk.pressed or mk.echo:
			return
		match mk.keycode:
			KEY_1:
				GameState.build_mode_changed.emit(GameConfig.Build.TOWER)
			KEY_2:
				GameState.build_mode_changed.emit(GameConfig.Build.MINE)
			KEY_3:
				GameState.build_mode_changed.emit(GameConfig.Build.WALL)
			KEY_ESCAPE:
				GameState.build_mode_changed.emit(-1)
				_clear_selection()


func _set_mode(kind: int) -> void:
	selected = kind
	if kind >= 0:
		_clear_selection()
	queue_redraw()


# ============================================================
#  查看建筑
# ============================================================
func _select_at(cell: Vector2i) -> void:
	var b = Board.get_building(cell)
	if b == _sel:
		queue_redraw()
		return
	_sel = b
	GameState.building_selected.emit(_sel)
	queue_redraw()


func _clear_selection() -> void:
	if _sel == null:
		return
	_sel = null
	GameState.building_selected.emit(null)
	queue_redraw()


# ============================================================
#  建造
# ============================================================
func _try_place(c: Vector2i) -> void:
	if selected < 0:
		return

	var def := GameConfig.build_def(selected)
	if def.is_empty():
		return

	if not Board.is_free(c):
		GameState.notice.emit("这里不能建造")
		return

	if not GameState.try_spend(def["cost"]):
		GameState.notice.emit("金币不足")
		return

	var scene: PackedScene = load(def["scene"])
	var b := scene.instantiate() as Building
	_buildings_root.add_child(b)   # 先入树，让 _ready 初始化 is_wall 等属性
	b.place(c)                    # 再登记到棋盘

	queue_redraw()


# ============================================================
#  绘制
# ============================================================
func _draw() -> void:
	var cell := GameConfig.CELL
	var half := cell * 0.5

	# 建造预览
	if selected >= 0 and Board.in_bounds(hover.x, hover.y):
		var def := GameConfig.build_def(selected)
		var ok: bool = Board.is_free(hover) and GameState.can_afford(def["cost"])
		var col: Color = GameConfig.C_OK if ok else GameConfig.C_BAD
		var c := Board.cell_to_world(hover)
		var rect := Rect2(c - Vector2(half, half), Vector2(cell, cell))
		draw_rect(rect, Color(col.r, col.g, col.b, 0.22), true)
		draw_rect(rect, col, false, 2.0)

		if selected == GameConfig.Build.TOWER:
			draw_arc(c, 5.0 * cell, 0.0, TAU, 64,
					Color(col.r, col.g, col.b, 0.45), 1.5, true)

	# 选中高亮
	if _sel != null and is_instance_valid(_sel):
		var p: Vector2 = _sel.global_position
		var r := Rect2(p - Vector2(half, half), Vector2(cell, cell))
		draw_rect(r, Color(1, 1, 1, 0.12), true)
		draw_rect(r, Color(1, 1, 1, 0.85), false, 2.0)
		_draw_corners(p, half + 3.0, Color(1, 1, 1, 0.9))
		if int(_sel.kind) == GameConfig.Build.TOWER:
			draw_arc(p, float(_sel.range_cells) * cell, 0.0, TAU, 64,
					Color(GameConfig.C_TOWER.r, GameConfig.C_TOWER.g, GameConfig.C_TOWER.b, 0.45), 1.5, true)

	# 悬停已建成的箭塔 -> 显示其射程
	var hb = Board.get_building(hover)
	if hb != null and is_instance_valid(hb) and hb != _sel and int(hb.kind) == GameConfig.Build.TOWER:
		draw_arc(hb.global_position, float(hb.range_cells) * cell, 0.0, TAU, 64,
				Color(GameConfig.C_TOWER.r, GameConfig.C_TOWER.g, GameConfig.C_TOWER.b, 0.35), 1.5, true)


func _draw_corners(p: Vector2, r: float, col: Color) -> void:
	var seg := 6.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := p + Vector2(sx * r, sy * r)
			draw_line(corner, corner - Vector2(sx * seg, 0.0), col, 2.0)
			draw_line(corner, corner - Vector2(0.0, sy * seg), col, 2.0)
