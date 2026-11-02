extends Node2D
## 进入界面「无妄之灾」
##   · 背景：assets/menu_bg.jpg（末日熔岩山谷），等比裁切铺满 1280×720
##   · 上层：暗化渐变保证文字可读 + 主标题 / 副标题 + 四枚按钮（开始 / 英雄 / 联机 / 退出）
##   · 回车 / 空格亦可开始；联机模式为占位入口

const MAIN_SCENE := "res://scenes/main.tscn"
const HERO_SCENE := "res://scenes/hero_select.tscn"
const BG_PATH := "res://assets/menu_bg.jpg"

var _font: SystemFont
var _bg: TextureRect
var _time := 0.0
var _start_btn: Button
var _hero_btn: Button
var _online_btn: Button
var _quit_btn: Button
var _hero_lb: Label
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Noto Sans CJK SC", "SimHei", "sans-serif",
	])
	_build_background()
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.6, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
			_start_game()


# ============================================================
#  背景：图片等比裁切铺满 + 上下暗化
# ============================================================
func _build_background() -> void:
	_bg = TextureRect.new()
	_bg.name = "Background"
	# 父节点是 Node2D（非 Control），锚点不可靠：直接给定 1280×720 的固定尺寸
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(1280, 720)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.texture = _load_bg_texture()
	add_child(_bg)

	# 顶部 / 底部暗化：保证标题与按钮在任何亮度下都清晰
	var top := ColorRect.new()
	top.color = Color(0.02, 0.025, 0.035, 0.55)
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 220)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var bottom := ColorRect.new()
	bottom.color = Color(0.015, 0.018, 0.025, 0.72)
	bottom.position = Vector2(0, 390)
	bottom.size = Vector2(1280, 330)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)


## 优先走导入资源；若图片尚未导入则在运行时直接读取
func _load_bg_texture() -> Texture2D:
	if ResourceLoader.exists(BG_PATH):
		var tex := load(BG_PATH) as Texture2D
		if tex != null:
			return tex
	var img := Image.load_from_file(ProjectSettings.globalize_path(BG_PATH))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	push_warning("开始界面背景加载失败：%s" % BG_PATH)
	return null


# ============================================================
#  UI 构建
# ============================================================
func _build_ui() -> void:
	var title := Label.new()
	title.text = "无妄之灾"
	title.position = Vector2(0, 96)
	title.size = Vector2(1280, 130)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.05, 0.04, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	add_child(title)

	var sub := Label.new()
	sub.text = "T H E   U N B I D D E N   C A L A M I T Y"
	sub.position = Vector2(0, 226)
	sub.size = Vector2(1280, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", _font)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.78, 0.52, 0.40, 0.85))
	add_child(sub)

	var tag := Label.new()
	tag.text = "天 降 无 妄 之 灾 · 塔 在 人 在"
	tag.position = Vector2(0, 256)
	tag.size = Vector2(1280, 22)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", _font)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.62, 0.55, 0.48, 0.9))
	add_child(tag)

	# 四枚按钮
	_start_btn = _make_btn("开 始 游 戏", Rect2(530, 430, 220, 56), 23,
			Color(0.78, 0.22, 0.14))
	_start_btn.pressed.connect(_start_game)

	_hero_btn = _make_btn("英 雄 选 择", Rect2(530, 496, 220, 48), 18,
			Color(0.92, 0.56, 0.20))
	_hero_btn.pressed.connect(_open_hero_select)

	_online_btn = _make_btn("联 机 模 式", Rect2(530, 554, 220, 40), 16,
			Color(0.36, 0.62, 0.95))
	_online_btn.pressed.connect(_on_online_pressed)

	_quit_btn = _make_btn("退 出 游 戏", Rect2(530, 604, 220, 36), 15,
			Color(0.48, 0.48, 0.52))
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())

	_hero_lb = Label.new()
	_hero_lb.position = Vector2(530, 650)
	_hero_lb.size = Vector2(220, 20)
	_hero_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_lb.add_theme_font_override("font", _font)
	_hero_lb.add_theme_font_size_override("font_size", 13)
	add_child(_hero_lb)
	_refresh_hero_label()

	_toast = Label.new()
	_toast.position = Vector2(390, 676)
	_toast.size = Vector2(500, 22)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_override("font", _font)
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.add_theme_color_override("font_color", Color(0.58, 0.80, 1.0))
	_toast.modulate.a = 0.0
	add_child(_toast)

	var hint := Label.new()
	hint.text = "WASD 移动 · 鼠标 / G 互动 · 1~9 选塔 · I 改造 · Q 英雄技能 · 守住 100 波"
	hint.position = Vector2(0, 700)
	hint.size = Vector2(1280, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.58, 0.53, 0.47, 0.9))
	add_child(hint)


func _on_online_pressed() -> void:
	_toast.text = "联机模式开发中，敬请期待"
	_toast_t = 2.0
	_toast.modulate.a = 1.0


func _refresh_hero_label() -> void:
	var hero: Dictionary = GameConfig.HEROES.get(GameState.hero_id, {})
	if hero.is_empty():
		_hero_lb.text = "当前英雄：未选择"
		return
	_hero_lb.text = "当前英雄：%s" % hero["name"]
	_hero_lb.add_theme_color_override("font_color", hero["color"])


func _make_btn(text: String, rect: Rect2, font_size: int, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1, 0.96, 0.88))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.90, 0.72))
	b.add_theme_stylebox_override("normal", _btn_style(
			Color(0.06, 0.055, 0.06, 0.78), Color(accent.r, accent.g, accent.b, 0.60)))
	b.add_theme_stylebox_override("hover", _btn_style(
			Color(0.12, 0.10, 0.10, 0.90), accent))
	b.add_theme_stylebox_override("pressed", _btn_style(
			Color(0.04, 0.04, 0.045, 0.95), accent))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(b)   # 必须入树，否则按钮既不显示也收不到点击
	return b


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	return sb


func _start_game() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _open_hero_select() -> void:
	get_tree().change_scene_to_file(HERO_SCENE)