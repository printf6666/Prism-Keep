extends Node2D
## 开始界面「无妄之灾」：纯代码绘制的末日门面
##   · 血月 + 两层废墟天际线 + 落灰 / 升腾余烬 + 闪烁主标题
##   · 英雄卡直接摆在界面上：点卡即切换英雄（炎拳 / 森之主 / 圣女）
##   · 游戏开始 → main.tscn；退出游戏 → 关闭程序；回车亦可开始

const MAIN_SCENE := "res://scenes/main.tscn"

var _font: SystemFont
var _ash: Array = []       # 落灰 {pos, v, drift}
var _embers: Array = []    # 余烬 {pos, v, phase}
var _skyline_far: Array = []   # 远景楼群多边形
var _skyline_near: Array = []  # 近景楼群多边形
var _windows: Array = []       # 零星亮窗 {pos, warm}
var _hero_cards: Array = []    # 英雄卡 {id, panel, status}
var _time := 0.0
var _start_btn: Button
var _quit_btn: Button


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Noto Sans CJK SC", "SimHei", "sans-serif",
	])
	_gen_scenery()
	_build_ui()
	_refresh_hero_cards()


func _process(delta: float) -> void:
	_time += delta
	# 落灰：缓缓下飘，出界回顶
	for a in _ash:
		a["pos"].y += a["v"] * delta
		a["pos"].x += a["drift"] * delta
		if a["pos"].y > 730.0:
			a["pos"].y = -10.0
			a["pos"].x = randf_range(0.0, 1280.0)
	# 余烬：自下而上飘散，左右轻摆
	for e in _embers:
		e["pos"].y -= e["v"] * delta
		e["pos"].x += sin(_time * 2.0 + e["phase"]) * 14.0 * delta
		if e["pos"].y < -10.0:
			e["pos"].y = 730.0
			e["pos"].x = randf_range(0.0, 1280.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
			_start_game()


# ============================================================
#  UI 构建
# ============================================================
func _build_ui() -> void:
	# 英雄卡：三张并排，点卡即切换英雄（选中卡亮边框 + ✓）
	var row := HBoxContainer.new()
	row.position = Vector2(1280.0 / 2.0 - 424.0, 392.0)
	row.size = Vector2(848.0, 174.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	for id in GameConfig.HEROES:
		var hero: Dictionary = GameConfig.HEROES[id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(256, 0)
		card.gui_input.connect(_on_card_input.bind(id))
		row.add_child(card)

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 3)
		cvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cvb)

		var name_lb := Label.new()
		name_lb.text = hero["name"]
		name_lb.add_theme_font_override("font", _font)
		name_lb.add_theme_font_size_override("font_size", 22)
		name_lb.add_theme_color_override("font_color", hero["color"])
		name_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(name_lb)

		var kind_lb := Label.new()
		kind_lb.text = "主动技能 [Q] · 冷却 %d 分" % int(hero["skill_cd"] / 60.0) \
				if hero.get("active", false) else "被动光环 · 范围增益"
		kind_lb.add_theme_font_override("font", _font)
		kind_lb.add_theme_font_size_override("font_size", 12)
		kind_lb.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		kind_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kind_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(kind_lb)

		var desc := Label.new()
		desc.text = hero["desc"]
		desc.add_theme_font_override("font", _font)
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(0, 66)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(desc)

		var status := Label.new()
		status.add_theme_font_override("font", _font)
		status.add_theme_font_size_override("font_size", 13)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(status)

		_hero_cards.append({"id": id, "panel": card, "status": status})

	# 游戏开始 / 退出
	_start_btn = _make_btn("游 戏 开 始", Rect2(530, 590, 220, 54), 22,
			Color(0.75, 0.2, 0.15))
	_start_btn.pressed.connect(_start_game)
	_quit_btn = _make_btn("退 出 游 戏", Rect2(530, 652, 220, 36), 14,
			Color(0.45, 0.45, 0.48))
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())

	# 底部操作速记
	var hint := Label.new()
	hint.text = "WASD 移动 · 鼠标 / G 互动 · 1~9 选塔 · I 改造 · Q 英雄技能 · 守住 100 波"
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	hint.position = Vector2(0, 700)
	hint.size = Vector2(1280, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


## 点英雄卡即切换英雄（所见即所得，选中卡亮边框 + ✓）
func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.hero_id = id
		_refresh_hero_cards()


func _refresh_hero_cards() -> void:
	for c in _hero_cards:
		var sel: bool = c["id"] == GameState.hero_id
		var col: Color = GameConfig.HEROES[c["id"]]["color"]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.08, 0.10, 0.92 if sel else 0.75)
		sb.border_color = Color(col.r, col.g, col.b, 1.0 if sel else 0.35)
		sb.set_border_width_all(2 if sel else 1)
		sb.set_corner_radius_all(8)
		c["panel"].add_theme_stylebox_override("panel", sb)
		c["status"].text = "✓ 已选择" if sel else "点 击 选 择"
		c["status"].add_theme_color_override("font_color",
				Color(col.r, col.g, col.b) if sel else Color(0.5, 0.48, 0.42))


func _make_btn(text: String, rect: Rect2, font_size: int, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.7))
	b.add_theme_stylebox_override("normal", _btn_style(
			Color(0.09, 0.08, 0.10, 0.92), Color(accent.r, accent.g, accent.b, 0.55)))
	b.add_theme_stylebox_override("hover", _btn_style(
			Color(0.13, 0.11, 0.13, 0.95), accent))
	b.add_theme_stylebox_override("pressed", _btn_style(
			Color(0.05, 0.05, 0.06, 1.0), accent))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


func _start_game() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


# ============================================================
#  场景生成（所有随机数烘焙于 _ready，绘制期零随机）
# ============================================================
func _gen_scenery() -> void:
	for i in 90:
		_ash.append({"pos": Vector2(randf_range(0.0, 1280.0), randf_range(-10.0, 730.0)),
				"v": randf_range(14.0, 34.0), "drift": randf_range(-8.0, 8.0),
				"s": randf_range(0.8, 1.8)})
	for i in 22:
		_embers.append({"pos": Vector2(randf_range(0.0, 1280.0), randf_range(80.0, 730.0)),
				"v": randf_range(18.0, 42.0), "phase": randf() * TAU,
				"s": randf_range(1.0, 2.2)})

	# 两层废墟天际线：远层高而灰、近层矮而黑，楼顶带坍塌缺口
	for layer in 2:
		var items: Array = []
		var x := randf_range(-70.0, -20.0)
		while x < 1300.0:
			var w := randf_range(55.0, 135.0)
			var top: float
			if layer == 0:
				top = randf_range(430.0, 560.0)
			else:
				top = randf_range(500.0, 640.0)
			var notches: Array = []
			for n in (1 + int(randf() * 2.0)):
				notches.append({"x": randf_range(0.15, 0.85), "w": randf_range(8.0, 22.0)})
			items.append({"x": x, "w": w, "top": top, "notches": notches})
			x += w + randf_range(3.0, 24.0)
		if layer == 0:
			_skyline_far = items
		else:
			_skyline_near = items

	# 零星亮窗（绝大多数是黑的）
	for i in 26:
		var layer_items: Array = _skyline_far if randf() < 0.5 else _skyline_near
		var b: Dictionary = layer_items[randi() % layer_items.size()]
		var wx: float = b["x"] + randf_range(6.0, b["w"] - 6.0)
		var wy: float = b["top"] + randf_range(8.0, 720.0 - b["top"] - 8.0)
		_windows.append({"pos": Vector2(wx, wy), "warm": randf() < 0.6})


# ============================================================
#  绘制
# ============================================================
func _draw() -> void:
	# 夜空：四角渐变（暗黑 → 暗红地平线）
	draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([
				Color(0.045, 0.045, 0.06), Color(0.075, 0.05, 0.05),
				Color(0.11, 0.055, 0.045), Color(0.035, 0.032, 0.04),
			]))

	# 血月：暗红圆 + 内芯 + 双层晕
	draw_circle(Vector2(960, 185), 128.0, Color(0.30, 0.08, 0.07, 0.35))
	draw_circle(Vector2(960, 185), 96.0, Color(0.36, 0.10, 0.08, 0.9))
	draw_circle(Vector2(960, 185), 78.0, Color(0.44, 0.13, 0.10, 0.9))
	draw_arc(Vector2(960, 185), 100.0, 0.0, TAU, 48, Color(0.55, 0.16, 0.12, 0.25), 2.0, true)

	# 巨大骷髅纹章（极淡，呼应死神）
	_draw_skull(Vector2(300, 240), 1.0)

	# 废墟天际线：远层 → 近层
	for b in _skyline_far:
		_draw_ruin(b, Color(0.055, 0.05, 0.055))
	for b in _skyline_near:
		_draw_ruin(b, Color(0.032, 0.029, 0.031))

	# 亮窗：废墟里零星的幸存者灯火
	for w in _windows:
		var c: Color = Color(0.85, 0.55, 0.2, 0.55) if w["warm"] else Color(0.9, 0.3, 0.2, 0.4)
		draw_rect(Rect2(w["pos"], Vector2(3.0, 4.0)), c, true)

	# 地面：底部压暗
	draw_rect(Rect2(0, 640, 1280, 80), Color(0.02, 0.02, 0.025, 0.85), true)

	# 主标题：无妄之灾（暗红辉光 + 抖动的骨白主体）
	var flicker := 0.86 + 0.10 * sin(_time * 2.6)
	if fmod(_time, 4.1) < 0.07:
		flicker *= 0.55   # 偶发闪烁
	var title_col := Color(0.92, 0.88, 0.78, flicker)
	for off in [Vector2(3, 3), Vector2(-2, 2), Vector2(2, -2)]:
		draw_string(_font, Vector2(off.x, 226.0 + off.y), "无妄之灾",
				HORIZONTAL_ALIGNMENT_CENTER, 1280, 96, Color(0.35, 0.08, 0.08, 0.55 * flicker))
	draw_string(_font, Vector2(0, 224.0), "无妄之灾",
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 96, title_col)

	# 血色斜杠划过标题下方
	draw_set_transform(Vector2(640, 260.0), deg_to_rad(-4.0), Vector2.ONE)
	draw_rect(Rect2(-190, -3, 380, 5), Color(0.55, 0.12, 0.10, 0.7 * flicker), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 副标题
	draw_string(_font, Vector2(0, 298.0), "P R I S M   K E E P",
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(0.5, 0.42, 0.4, 0.75 * flicker))
	draw_string(_font, Vector2(0, 330.0), "天 降 无 妄 之 灾 · 塔 在 人 在",
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 15, Color(0.45, 0.38, 0.34, 0.7))

	# 落灰与余烬
	for a in _ash:
		draw_circle(a["pos"], a["s"], Color(0.45, 0.42, 0.38, 0.35))
	for e in _embers:
		var ea := 0.5 + 0.3 * sin(_time * 6.0 + e["phase"])
		draw_circle(e["pos"], e["s"], Color(0.9, 0.4, 0.15, ea))


## 淡淡的骷髅纹章
func _draw_skull(center: Vector2, k: float) -> void:
	var bone := Color(0.75, 0.72, 0.62, 0.09)
	var dark := Color(0.1, 0.06, 0.08, 0.10)
	draw_circle(center, 46.0 * k, bone)
	draw_rect(Rect2(center + Vector2(-20.0 * k, 8.0 * k), Vector2(40.0 * k, 22.0 * k)), bone, true)
	draw_circle(center + Vector2(-13.0 * k, -6.0 * k), 7.5 * k, dark)
	draw_circle(center + Vector2(13.0 * k, -6.0 * k), 7.5 * k, dark)
	draw_rect(Rect2(center + Vector2(-4.0 * k, 4.0 * k), Vector2(8.0 * k, 7.0 * k)), dark, true)


## 废墟楼：楼体 + 坍塌缺口 + 楼顶断柱
func _draw_ruin(b: Dictionary, col: Color) -> void:
	var x: float = b["x"]
	var w: float = b["w"]
	var top: float = b["top"]
	draw_rect(Rect2(x, top, w, 720.0 - top), col, true)
	for n in b["notches"]:
		var nx: float = x + w * n["x"]
		var nw: float = n["w"]
		draw_rect(Rect2(nx, top, nw, 7.0), Color(0.03, 0.028, 0.03), true)
	# 楼顶断柱
	if b["w"] > 90.0:
		draw_rect(Rect2(x + w * 0.7, top - 10.0, 4.0, 12.0), col, true)
