extends Node2D
## 建造交互 + 建筑查看（面朝格子版）
##   · 互动只作用于角色面前一格
##   · F = 空地互动：按 1~4（或点建造栏）选建筑 -> 面向空地按 F 放置
##   · G = 建筑互动：面前有建筑 -> 选中查看（升级 / 拆除），再按一次取消
##   · 右键 / ESC 取消建造、取消选中

var selected := -1              # 当前要建造的类型，-1 = 非建造模式
var front := Vector2i(-1, -1)   # 角色面前一格（所有互动的目标）

var _sel: Node = null           # 当前查看中的建筑
var _front_b = null             # 面前格里的建筑（用于检测新建 / 被拆后刷新）
var _buildings_root: Node2D
var _player: Node2D
var _near_retool := false       # 角色是否靠近改造车间
var _retool_node = null


func _ready() -> void:
	z_index = 8
	_buildings_root = get_parent().get_node("Buildings")
	_player = get_tree().get_first_node_in_group("player")
	GameState.build_mode_changed.connect(_set_mode)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var c: Vector2i = _player.front_cell()
	var b = Board.get_building(c)
	if c != front or b != _front_b:
		front = c
		_front_b = b
		queue_redraw()
	_update_retool_proximity()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
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
			KEY_4:
				GameState.build_mode_changed.emit(GameConfig.Build.FROST)
			KEY_5:
				GameState.build_mode_changed.emit(GameConfig.Build.BARRICADE)
			KEY_6:
				GameState.build_mode_changed.emit(GameConfig.Build.CANNON)
			KEY_7:
				GameState.build_mode_changed.emit(GameConfig.Build.RETOOL)
			KEY_8:
				GameState.build_mode_changed.emit(GameConfig.Build.FLAME)
			KEY_F:
				_interact_ground()
				get_viewport().set_input_as_handled()
			KEY_G:
				_interact_building()
				get_viewport().set_input_as_handled()
			KEY_I:
				if _near_retool:
					GameState.set_retool_menu(not GameState.retool_menu_open)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				GameState.build_mode_changed.emit(-1)
				_clear_selection()
				GameState.set_retool_menu(false)


func _set_mode(kind: int) -> void:
	selected = kind
	if kind >= 0:
		_clear_selection()
	queue_redraw()


# ============================================================
#  F / G：与面前一格互动
# ============================================================
## F：与面前的空地互动 —— 建造模式下放置，未选建筑 / 面前不是空地时提示
func _interact_ground() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not Board.in_bounds(front.x, front.y):
		return

	if selected >= 0:
		_try_place(front)
	elif Board.get_building(front) != null:
		GameState.notice.emit("面前是建筑，按 G 查看")
	else:
		GameState.notice.emit("按 1~8 选择建筑，面向空地按 F 建造")


## G：与面前的建筑互动 —— 选中查看详情，再按一次取消
func _interact_building() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not Board.in_bounds(front.x, front.y):
		return

	var b = Board.get_building(front)
	if b == null:
		GameState.notice.emit("面前没有建筑")
		return
	if b == _sel:
		_clear_selection()
	else:
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
#  改造车间：靠近检测 + I 键互动
# ============================================================
func _update_retool_proximity() -> void:
	var node = _find_near_retool()
	var near := node != null
	if near != _near_retool:
		_near_retool = near
		_retool_node = node
		if not near:
			GameState.set_retool_menu(false)   # 走远自动关闭菜单
		queue_redraw()
	elif near and node != _retool_node:
		_retool_node = node


func _find_near_retool():
	## 角色是否在某个改造车间的占地范围外一圈以内
	if _player == null or not is_instance_valid(_player):
		return null
	var pc := Board.cell_of(_player.global_position)
	for b in Board.buildings.values():
		if not is_instance_valid(b) or int(b.kind) != GameConfig.Build.RETOOL:
			continue
		var c: Vector2i = b.cell
		if pc.x >= c.x - 1 and pc.x <= c.x + b.footprint.x \
				and pc.y >= c.y - 1 and pc.y <= c.y + b.footprint.y:
			return b
	return null


# ============================================================
#  建造
# ============================================================
func _try_place(c: Vector2i) -> void:
	if selected < 0:
		return

	var def := GameConfig.build_def(selected)
	if def.is_empty():
		return

	# 金矿只能建在矿山格上
	if selected == GameConfig.Build.MINE and not Board.is_ore(c):
		GameState.notice.emit("金矿只能建在矿山格上")
		return

	# 多格建筑：整个占地范围都必须可建
	var fp: Vector2i = def.get("footprint", Vector2i.ONE)
	if not Board.is_free_area(c, fp):
		GameState.notice.emit("这里不能建造")
		return

	# 角色不能站在建造范围内
	if _player != null and is_instance_valid(_player):
		var pc := Board.cell_of(_player.global_position)
		if pc.x >= c.x and pc.x < c.x + fp.x and pc.y >= c.y and pc.y < c.y + fp.y:
			GameState.notice.emit("角色站在建造范围内")
			return

	if not GameState.try_spend(def["cost"]):
		GameState.notice.emit("金币不足")
		return

	var scene: PackedScene = load(def["scene"])
	var b := scene.instantiate() as Building
	if selected == GameConfig.Build.BARRICADE:
		b.barricade = true   # add_child 前设变体，_ready 按它初始化属性
	_buildings_root.add_child(b)   # 先入树，让 _ready 初始化 is_wall 等属性
	b.place(c)                    # 再登记到棋盘

	queue_redraw()


# ============================================================
#  绘制
# ============================================================
func _draw() -> void:
	var cell := GameConfig.CELL
	var half := cell * 0.5
	if not Board.in_bounds(front.x, front.y):
		return
	var c := Board.cell_to_world(front)
	var rect := Rect2(c - Vector2(half, half), Vector2(cell, cell))

	# 金矿建造模式：高亮全部矿山格，指明可落点
	if selected == GameConfig.Build.MINE:
		for oc in Board.ore_cells():
			var ow := Board.cell_to_world(oc)
			draw_rect(Rect2(ow - Vector2(half, half), Vector2(cell, cell)),
					Color(GameConfig.C_MINE.r, GameConfig.C_MINE.g, GameConfig.C_MINE.b, 0.10), true)

	# 建造预览：以面前格为左上角显示绿 / 红幽灵（多格建筑覆盖整个占地范围）
	if selected >= 0:
		var def := GameConfig.build_def(selected)
		var fp: Vector2i = def.get("footprint", Vector2i.ONE)
		var ok: bool = Board.is_free_area(front, fp) and GameState.can_afford(def["cost"])
		if selected == GameConfig.Build.MINE:
			ok = ok and Board.is_ore(front)
		var col: Color = GameConfig.C_OK if ok else GameConfig.C_BAD
		var ghost := Rect2(rect.position, Vector2(fp) * cell)
		draw_rect(ghost, Color(col.r, col.g, col.b, 0.22), true)
		draw_rect(ghost, col, false, 2.0)

		if GameConfig.is_tower_kind(selected):
			var rr := 5.0 if selected == GameConfig.Build.TOWER \
					else 4.0 if selected == GameConfig.Build.FROST \
					else 4.5
			draw_arc(c, rr * cell, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.45), 1.5, true)
	else:
		# 非建造模式：面前格提示框 —— 空地淡框，建筑亮框（塔顺带显示射程）
		var fb = Board.get_building(front)
		if fb != null and is_instance_valid(fb):
			var ac: Color = GameConfig.C_BASE
			draw_rect(rect, Color(ac.r, ac.g, ac.b, 0.10), true)
			draw_rect(rect, Color(ac.r, ac.g, ac.b, 0.80), false, 2.0)
			if fb != _sel and GameConfig.is_tower_kind(int(fb.kind)):
				draw_arc(fb.global_position, float(fb.range_cells) * cell, 0.0, TAU, 64,
						Color(fb.tint.r, fb.tint.g, fb.tint.b, 0.35), 1.5, true)
		else:
			var dim: Color = GameConfig.C_TEXT_DIM
			draw_rect(rect, Color(dim.r, dim.g, dim.b, 0.25), false, 1.0)

	# 选中高亮（多格建筑覆盖整个占地范围）
	if _sel != null and is_instance_valid(_sel):
		var fh: float = _sel.footprint.x * cell * 0.5
		var p: Vector2 = _sel.global_position
		var r := Rect2(p - Vector2(fh, fh), Vector2(fh * 2.0, fh * 2.0))
		draw_rect(r, Color(1, 1, 1, 0.12), true)
		draw_rect(r, Color(1, 1, 1, 0.85), false, 2.0)
		_draw_corners(p, fh + 3.0, Color(1, 1, 1, 0.9))
		if GameConfig.is_tower_kind(int(_sel.kind)):
			draw_arc(p, float(_sel.range_cells) * cell, 0.0, TAU, 64,
					Color(_sel.tint.r, _sel.tint.g, _sel.tint.b, 0.45), 1.5, true)

	# 靠近改造车间：头顶提示按 I
	if _near_retool and not GameState.retool_menu_open \
			and _retool_node != null and is_instance_valid(_retool_node):
		var hp_top: Vector2 = _retool_node.global_position \
				- Vector2(0.0, _retool_node.footprint.y * cell * 0.5 + 16.0)
		draw_string(ThemeDB.fallback_font, hp_top + Vector2(-70.0, 0.0), "按 I 打开改造",
				HORIZONTAL_ALIGNMENT_CENTER, 140, 13, GameConfig.C_BASE)


func _draw_corners(p: Vector2, r: float, col: Color) -> void:
	var seg := 6.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := p + Vector2(sx * r, sy * r)
			draw_line(corner, corner - Vector2(sx * seg, 0.0), col, 2.0)
			draw_line(corner, corner - Vector2(0.0, sy * seg), col, 2.0)
