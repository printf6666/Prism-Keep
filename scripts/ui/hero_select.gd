extends Node2D
## 英雄选择界面：独立场景，三张英雄大卡片
##   · 点击卡片选定英雄（亮边框 + ✓），随时可换
##   · 「开始游戏」用当前英雄直接进入战场；「返回」回到进入界面

const MAIN_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/start_menu.tscn"
const HERO_PORTRAIT := preload("res://assets/hero_flame_fist.png")

var _font: SystemFont
var _cards: Array = []     # {id, panel, status}
var _time := 0.0
var _back_btn: Button
var _start_btn: Button


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Noto Sans CJK SC", "SimHei", "sans-serif",
	])
	_build_ui()
	_refresh_cards()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_back()


# ============================================================
#  UI
# ============================================================
func _build_ui() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(1280.0 / 2.0 - 448.0, 250.0)
	row.size = Vector2(896.0, 250.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	add_child(row)

	for id in GameConfig.HEROES:
		var hero: Dictionary = GameConfig.HEROES[id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(270, 0)
		card.gui_input.connect(_on_card_input.bind(id))
		row.add_child(card)

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 6)
		cvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cvb)

		var name_lb := Label.new()
		name_lb.text = hero["name"]
		name_lb.add_theme_font_override("font", _font)
		name_lb.add_theme_font_size_override("font_size", 26)
		name_lb.add_theme_color_override("font_color", hero["color"])
		name_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(name_lb)

		# 炎拳的立绘预览（其余英雄暂用色块占位）
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(0, 96)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if id == "flame_fist":
			portrait.texture = HERO_PORTRAIT
		cvb.add_child(portrait)

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
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(0, 96)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(desc)

		var status := Label.new()
		status.add_theme_font_override("font", _font)
		status.add_theme_font_size_override("font_size", 14)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.add_child(status)

		_cards.append({"id": id, "panel": card, "status": status})

	_start_btn = _make_btn("开 始 游 戏", Rect2(530, 540, 220, 52), 21,
			Color(0.75, 0.2, 0.15))
	_start_btn.pressed.connect(_start_game)

	_back_btn = _make_btn("返 回", Rect2(530, 604, 220, 40), 15,
			Color(0.5, 0.5, 0.5))
	_back_btn.pressed.connect(_back)


func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.hero_id = id
		_refresh_cards()


func _refresh_cards() -> void:
	if _cards.is_empty():
		return
	for c in _cards:
		var sel: bool = c["id"] == GameState.hero_id
		var col: Color = GameConfig.HEROES[c["id"]]["color"]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.08, 0.10, 0.92 if sel else 0.72)
		sb.border_color = Color(col.r, col.g, col.b, 1.0 if sel else 0.32)
		sb.set_border_width_all(3 if sel else 1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
		c["panel"].add_theme_stylebox_override("panel", sb)
		c["status"].text = "✓ 已选择" if sel else "点 击 选 择"
		c["status"].add_theme_color_override("font_color",
				col if sel else Color(0.5, 0.48, 0.42))


func _make_btn(text: String, rect: Rect2, font_size: int, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85))
	b.add_theme_stylebox_override("normal", _btn_style(
			Color(0.09, 0.08, 0.10, 0.92), Color(accent.r, accent.g, accent.b, 0.55)))
	b.add_theme_stylebox_override("hover", _btn_style(
			Color(0.13, 0.11, 0.13, 0.95), accent))
	b.add_theme_stylebox_override("pressed", _btn_style(
			Color(0.05, 0.05, 0.06, 1.0), accent))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(b)   # 必须入树，否则按钮既不显示也收不到点击
	return b


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


func _start_game() -> void:
	if GameState.hero_id == "":
		GameState.hero_id = "flame_fist"
	get_tree().change_scene_to_file(MAIN_SCENE)


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


# ============================================================
#  绘制：末日底色 + 标题 + 余烬
# ============================================================
func _draw() -> void:
	draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([
				Color(0.04, 0.04, 0.055), Color(0.06, 0.045, 0.045),
				Color(0.09, 0.05, 0.042), Color(0.03, 0.028, 0.035),
			]))

	# 标题
	draw_string(_font, Vector2(0, 128.0), "选 择 你 的 英 雄",
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 44, Color(0.92, 0.86, 0.72))
	draw_set_transform(Vector2(640, 152.0), deg_to_rad(-3.0), Vector2.ONE)
	draw_rect(Rect2(-170, -2, 340, 4), Color(0.55, 0.12, 0.10, 0.7), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(_font, Vector2(0, 190.0), "不同的英雄改变你在战场上的职能 · 点击卡片即可切换",
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 14, Color(0.55, 0.5, 0.44))

	# 底部余烬
	for i in 26:
		var x := fmod(float(i) * 137.7 + _time * (12.0 + float(i) * 0.4), 1280.0)
		var y := fmod(720.0 - _time * (20.0 + float(i) * 0.8) + float(i) * 47.0, 720.0)
		draw_circle(Vector2(x, y), 1.4, Color(0.9, 0.4, 0.15, 0.4))