extends CanvasLayer
## HUD：全部用代码搭建（不依赖任何图片资源），中文字体走系统字体回退

var _root: Control

var _gold_label: Label
var _wave_label: Label
var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat

var _build_btns: Array = []
var _next_btn: Button
var _speed_btns: Array = []
var _pause_btn: Button
var _paused := false

var _sel_panel: PanelContainer
var _sel_name: Label
var _sel_hp: ProgressBar
var _sel_hp_fill: StyleBoxFlat
var _sel_hp_text: Label
var _sel_l1: Label
var _sel_l2: Label
var _sel: Node = null
var _up_btn: Button
var _sell_btn: Button
var _branch_box: VBoxContainer
var _branch_btns: Array = []

var _toast: Label
var _toast_t := 0.0

var _retool_panel: PanelContainer
var _sp_label: Label
var _retool_rows: Array = []

var _overlay: Control
var _result_label: Label
var _result_sub: Label

var _last_prep := -999


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_apply_theme()
	_build_info()
	_build_sel_panel()
	_build_retool_panel()
	_build_top_right()
	_build_minimap()
	_build_build_bar()
	_build_next_button()
	_build_toast()
	_build_overlay()
	_wire()

	_on_gold(GameState.gold)
	_on_base(GameState.base_hp, GameState.base_hp_max)
	_on_wave(GameState.wave, GameState.total_waves)


func _process(delta: float) -> void:
	_refresh_sel()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)


# ============================================================
#  主题与通用控件
# ============================================================
func _apply_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Noto Sans CJK SC", "Source Han Sans SC", "SimHei", "sans-serif",
	])
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 16
	_root.theme = th


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11, 0.90)
	sb.border_color = Color(0.20, 0.26, 0.34, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


func _btn_style(bg: Color, border: Color, width := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _mk_button(text: String, w: float, h: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", GameConfig.C_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.50, 0.58))
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.10, 0.13, 0.17, 0.95), Color(0.22, 0.28, 0.36)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.15, 0.19, 0.25, 0.98), Color(0.36, 0.44, 0.54)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.08, 0.11, 0.15, 1.0), GameConfig.C_BASE))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.07, 0.09, 0.12, 0.75), Color(0.15, 0.19, 0.24)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# ============================================================
#  左上信息面板
# ============================================================
func _build_info() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(18, 18)
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 23)
	_gold_label.add_theme_color_override("font_color", GameConfig.C_MINE)
	vb.add_child(_gold_label)

	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 16)
	_wave_label.add_theme_color_override("font_color", GameConfig.C_TEXT)
	vb.add_child(_wave_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	var tag := Label.new()
	tag.text = "大本营"
	tag.add_theme_color_override("font_color", GameConfig.C_TEXT_DIM)
	row.add_child(tag)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(148, 12)
	_hp_bar.show_percentage = false
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.16, 0.20, 1.0)
	bg.set_corner_radius_all(4)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = GameConfig.C_OK
	_hp_fill.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	row.add_child(_hp_bar)


# ============================================================
#  改造车间菜单（靠近车间按 I 打开）
# ============================================================
func _build_retool_panel() -> void:
	_retool_panel = PanelContainer.new()
	_retool_panel.name = "RetoolPanel"
	_retool_panel.add_theme_stylebox_override("panel", _panel_style())
	_retool_panel.position = Vector2(18, 400)
	_retool_panel.custom_minimum_size = Vector2(300, 0)
	_retool_panel.visible = false
	_root.add_child(_retool_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_retool_panel.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)

	var title := Label.new()
	title.text = "改造车间"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GameConfig.C_RETOOL)
	head.add_child(title)

	_sp_label = Label.new()
	_sp_label.add_theme_font_size_override("font_size", 16)
	_sp_label.add_theme_color_override("font_color", GameConfig.C_BASE)
	head.add_child(_sp_label)

	for i in GameConfig.RETOOL_BUFFS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)

		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 14)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lb)

		var bb := _mk_button("", 0.0, 30.0)
		bb.add_theme_font_size_override("font_size", 13)
		bb.pressed.connect(_on_buff_pressed.bind(i))
		row.add_child(bb)
		_retool_rows.append({"label": lb, "btn": bb, "idx": i})

	var tip := Label.new()
	tip.text = "技能点：击杀 Boss 300 / 重甲 50 / 小怪 1"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", GameConfig.C_TEXT_DIM)
	vb.add_child(tip)


func _on_buff_pressed(i: int) -> void:
	GameState.buy_buff(i)   # 失败（点数不足）时按钮本就置灰；成功后 skill_changed 触发刷新


func _on_retool_menu(open: bool) -> void:
	_retool_panel.visible = open
	if open:
		_refresh_retool()


func _on_skill_changed(_v: int) -> void:
	if _retool_panel != null and _retool_panel.visible:
		_refresh_retool()


func _refresh_retool() -> void:
	_sp_label.text = "技能点 %d" % GameState.skill_points
	for item in _retool_rows:
		var i: int = item["idx"]
		var def: Dictionary = GameConfig.RETOOL_BUFFS[i]
		var lv: int = GameState.buff_level(i)
		var maxed: bool = lv >= int(def["max_lv"])
		item["label"].text = "%s（%d/%d）" % [def["name"], lv, int(def["max_lv"])]
		var bb: Button = item["btn"]
		if maxed:
			bb.text = "已满级"
			bb.disabled = true
		else:
			bb.text = "升级 %d" % GameConfig.buff_cost(i, lv)
			bb.disabled = GameState.skill_points < GameConfig.buff_cost(i, lv)


# ============================================================
#  右上：倍速 / 暂停
# ============================================================
func _build_top_right() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -340.0
	bar.offset_top = 18.0
	bar.offset_right = -18.0
	bar.offset_bottom = 60.0
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 8)
	_root.add_child(bar)

	for m in [1.0, 2.0, 3.0]:
		var b := _mk_button("%d×" % int(m), 56.0, 42.0)
		var mult: float = m
		b.pressed.connect(func() -> void:
			GameState.speed_changed.emit(mult)
			_refresh_speed(mult))
		bar.add_child(b)
		_speed_btns.append({"btn": b, "mult": mult})

	_pause_btn = _mk_button("暂停", 68.0, 42.0)
	_pause_btn.pressed.connect(_toggle_pause)
	bar.add_child(_pause_btn)

	_refresh_speed(1.0)


func _refresh_speed(mult: float) -> void:
	for item in _speed_btns:
		var b: Button = item["btn"]
		var on: bool = is_equal_approx(float(item["mult"]), mult)
		if on:
			b.add_theme_stylebox_override("normal",
					_btn_style(Color(0.10, 0.20, 0.26, 1.0), GameConfig.C_BASE, 2))
			b.add_theme_color_override("font_color", GameConfig.C_BASE)
		else:
			b.add_theme_stylebox_override("normal",
					_btn_style(Color(0.10, 0.13, 0.17, 0.95), Color(0.22, 0.28, 0.36)))
			b.add_theme_color_override("font_color", GameConfig.C_TEXT)


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_btn.text = "继续" if _paused else "暂停"


# ============================================================
#  右上：小地图（倍速栏正下方）
# ============================================================
func _build_minimap() -> void:
	var mm := preload("res://scripts/ui/minimap.gd").new()
	mm.name = "Minimap"
	mm.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mm.offset_left = -178.0
	mm.offset_top = 70.0
	mm.offset_right = -18.0
	mm.offset_bottom = 230.0
	_root.add_child(mm)


# ============================================================
#  底部建造栏
# ============================================================
func _build_build_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -602.0
	bar.offset_right = 602.0
	bar.offset_top = -112.0
	bar.offset_bottom = -26.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	_root.add_child(bar)

	for kind in [GameConfig.Build.TOWER, GameConfig.Build.MINE, GameConfig.Build.WALL, GameConfig.Build.FROST, GameConfig.Build.BARRICADE, GameConfig.Build.CANNON, GameConfig.Build.RETOOL, GameConfig.Build.FLAME]:
		var def := GameConfig.build_def(kind)
		var b := _mk_button("", 140.0, 78.0)
		b.icon = Art.build_icon(kind, def["color"], 26)
		b.text = "  %s %d" % [def["name"], int(def["cost"])]
		b.tooltip_text = "%s（快捷键 %s）\n%s" % [def["name"], def["hotkey"], def["desc"]]
		var k: int = kind
		b.pressed.connect(func() -> void: GameState.build_mode_changed.emit(k))
		bar.add_child(b)
		_build_btns.append({"btn": b, "kind": k, "def": def})


func _build_next_button() -> void:
	_next_btn = _mk_button("下一波", 260.0, 44.0)
	_next_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_btn.offset_left = -130.0
	_next_btn.offset_right = 130.0
	_next_btn.offset_top = -166.0
	_next_btn.offset_bottom = -122.0
	_next_btn.pressed.connect(func() -> void: GameState.next_wave_pressed.emit())
	_root.add_child(_next_btn)


func _refresh_build_buttons(selected: int) -> void:
	for item in _build_btns:
		var b: Button = item["btn"]
		var def: Dictionary = item["def"]
		if int(item["kind"]) == selected:
			b.add_theme_stylebox_override("normal",
					_btn_style(Color(0.12, 0.18, 0.19, 1.0), def["color"], 2))
			b.add_theme_color_override("font_color", def["color"])
		else:
			b.add_theme_stylebox_override("normal",
					_btn_style(Color(0.10, 0.13, 0.17, 0.95), Color(0.22, 0.28, 0.36)))
			b.add_theme_color_override("font_color", GameConfig.C_TEXT)


# ============================================================
#  建筑详情面板（点击已部署建筑后出现）
# ============================================================
func _build_sel_panel() -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.add_theme_stylebox_override("panel", _panel_style())
	_sel_panel.position = Vector2(18, 134)
	_sel_panel.custom_minimum_size = Vector2(236, 0)
	_sel_panel.visible = false
	_root.add_child(_sel_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_sel_panel.add_child(vb)

	_sel_name = Label.new()
	_sel_name.add_theme_font_size_override("font_size", 19)
	vb.add_child(_sel_name)

	_sel_hp = ProgressBar.new()
	_sel_hp.custom_minimum_size = Vector2(204, 10)
	_sel_hp.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.16, 0.20, 1.0)
	bg.set_corner_radius_all(3)
	_sel_hp_fill = StyleBoxFlat.new()
	_sel_hp_fill.bg_color = GameConfig.C_OK
	_sel_hp_fill.set_corner_radius_all(3)
	_sel_hp.add_theme_stylebox_override("background", bg)
	_sel_hp.add_theme_stylebox_override("fill", _sel_hp_fill)
	vb.add_child(_sel_hp)

	_sel_hp_text = Label.new()
	_sel_hp_text.add_theme_font_size_override("font_size", 14)
	_sel_hp_text.add_theme_color_override("font_color", GameConfig.C_TEXT_DIM)
	vb.add_child(_sel_hp_text)

	_sel_l1 = Label.new()
	_sel_l1.add_theme_font_size_override("font_size", 15)
	_sel_l1.add_theme_color_override("font_color", GameConfig.C_TEXT)
	vb.add_child(_sel_l1)

	_sel_l2 = Label.new()
	_sel_l2.add_theme_font_size_override("font_size", 14)
	_sel_l2.add_theme_color_override("font_color", GameConfig.C_TEXT_DIM)
	vb.add_child(_sel_l2)

	# 满级塔的分支定型按钮（按选中建筑的 branch_options 动态生成）
	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override("separation", 6)
	vb.add_child(bvb)
	_branch_box = bvb

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	_up_btn = _mk_button("升级", 0.0, 34.0)
	_up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up_btn.add_theme_font_size_override("font_size", 15)
	_up_btn.pressed.connect(_on_upgrade_pressed)
	row.add_child(_up_btn)

	_sell_btn = _mk_button("拆除", 0.0, 34.0)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.add_theme_font_size_override("font_size", 15)
	_sell_btn.pressed.connect(_on_demolish_pressed)
	row.add_child(_sell_btn)


func _on_building_selected(b) -> void:
	_sel = b
	if b == null or not is_instance_valid(b):
		_sel = null
		_sel_panel.visible = false
		return

	_sel_panel.visible = true
	match int(b.kind):
		GameConfig.Build.TOWER:
			_sel_name.text = "箭塔" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_TOWER)
			_sel_l1.text = "攻击力 %d      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "射程 %d 格" % int(b.range_cells)
		GameConfig.Build.MINE:
			_sel_name.text = "金矿" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_MINE)
			_sel_l1.text = "产出 %d 金 / %d 秒" % [int(b.income), int(b.interval)]
			_sel_l2.text = "经济来源，被拆会断收入"
		GameConfig.Build.FROST:
			_sel_name.text = "寒冰塔" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_FROST)
			_sel_l1.text = "攻击力 %d      冰冻 %.1f 秒" % [int(b.damage), b.freeze_time]
			_sel_l2.text = "射程 %d 格，冻结期间无法行动" % int(b.range_cells)
		GameConfig.Build.FROST_STORM:
			_sel_name.text = "冰暴塔"
			_sel_name.add_theme_color_override("font_color", GameConfig.C_FROST_STORM)
			_sel_l1.text = "攻击力 %d（群伤）      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "射程 %d 格，3×3 爆炸并减速 50%（2.5 秒）" % int(b.range_cells)
		GameConfig.Build.FROST_BEAM:
			_sel_name.text = "不朽塔"
			_sel_name.add_theme_color_override("font_color", GameConfig.C_FROST_BEAM)
			_sel_l1.text = "激光 %d 伤害 / 秒（随锁定时间提升）" % int(GameConfig.BEAM_DPS)
			_sel_l2.text = "射程 %d 格，冻结锁定目标；增伤上限 Boss 3× / 重甲 5× / 其余不限" % int(b.range_cells)
		GameConfig.Build.TOWER_RAPID, GameConfig.Build.TOWER_RANGE, GameConfig.Build.FLAME_BLAZE:
			var bdef := GameConfig.build_def(int(b.kind))
			_sel_name.text = bdef["name"] + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", bdef["color"])
			_sel_l1.text = "攻击力 %d      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "射程 %d 格（分支定型）" % int(b.range_cells)
		GameConfig.Build.CANNON:
			_sel_name.text = "炮塔" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_CANNON)
			_sel_l1.text = "攻击力 %d      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "射程 %d 格" % int(b.range_cells)
		GameConfig.Build.CANNON_HEAVY:
			_sel_name.text = "重型炮"
			_sel_name.add_theme_color_override("font_color", GameConfig.C_CANNON_HEAVY)
			_sel_l1.text = "攻击力 %d      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "射程 %d 格，优先轰击血量上限最高的敌人" % int(b.range_cells)
		GameConfig.Build.CANNON_MORTAR:
			_sel_name.text = "迫击炮"
			_sel_name.add_theme_color_override("font_color", GameConfig.C_CANNON_MORTAR)
			_sel_l1.text = "攻击力 %d（群伤）      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "射程 %d 格，4×4 溅射，优先轰击敌人最密集处" % int(b.range_cells)
		GameConfig.Build.FLAME:
			_sel_name.text = "喷火器" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_FLAME)
			_sel_l1.text = "攻击力 %d（扇形群伤）      每秒 %d" % [int(b.damage), int(round(b.damage / b.fire_interval))]
			_sel_l2.text = "45° 扇形 %d 格，点燃：每秒烧 1% 最大生命值，持续 10 秒" % int(b.range_cells)
		GameConfig.Build.MAGMA:
			_sel_name.text = "熔岩塔"
			_sel_name.add_theme_color_override("font_color", GameConfig.C_MAGMA)
			_sel_l1.text = "投掷岩浆      间隔 %.1f 秒" % b.fire_interval
			_sel_l2.text = "射程 %d 格，岩浆灼烧 2%/秒（岩浆中翻倍），蔓延约 3 格" % int(b.range_cells)
		GameConfig.Build.WALL:
			_sel_name.text = "围墙" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_WALL)
			_sel_l1.text = "阻挡敌人前进"
			_sel_l2.text = "普通敌人不会攻击（重甲 / Boss 可强拆）"
		GameConfig.Build.BARRICADE:
			_sel_name.text = "路障" + _lv_text(b)
			_sel_name.add_theme_color_override("font_color", GameConfig.C_BARRICADE)
			_sel_l1.text = "嘲讽：路过的敌人都会攻击它"
			_sel_l2.text = "血量比围墙高，替塔吸收火力"
		GameConfig.Build.RETOOL:
			_sel_name.text = "改造车间"
			_sel_name.add_theme_color_override("font_color", GameConfig.C_RETOOL)
			_sel_l1.text = "5×5 功能建筑，靠近按 I 打开改造菜单"
			_sel_l2.text = "易被敌人攻击，注意保护"
	_rebuild_branch_buttons()
	_refresh_sel()


func _lv_text(b) -> String:
	return "" if int(b.level) <= 1 else "  Lv.%d" % int(b.level)


func _refresh_sel() -> void:
	if _sel == null:
		return
	if not is_instance_valid(_sel):
		_sel = null
		_sel_panel.visible = false
		return

	var mx: float = _sel.max_hp
	var hp: float = _sel.hp
	_sel_hp.max_value = mx
	_sel_hp.value = hp
	_sel_hp_text.text = "血量 %d / %d" % [int(ceil(hp)), int(mx)]

	var p := 0.0
	if mx > 0.0:
		p = clampf(hp / mx, 0.0, 1.0)
	var c: Color = GameConfig.C_OK
	if p <= 0.25:
		c = GameConfig.C_BAD
	elif p <= 0.55:
		c = Color(1.0, 0.78, 0.28)
	_sel_hp_fill.bg_color = c

	# 升级 / 拆除按钮（金币变化时可用状态实时刷新）
	var up: bool = _sel.can_upgrade()
	_up_btn.visible = up
	if up:
		var cost: float = _sel.upgrade_cost()
		_up_btn.text = "升级 %d" % int(cost)
		_up_btn.disabled = not GameState.can_afford(cost)
	_sell_btn.text = "拆除 +%d" % int(roundf(_sel.refund_value()))

	# 定型 / 改造按钮：满级未定型 = 定型；已定型 + 场上有改造车间 = 改造
	var show_btns: bool = _sel.can_branch() or _sel.can_retrofit()
	var btn_cost: float = _sel.branch_cost() if _sel.can_branch() else _sel.retrofit_cost()
	for item in _branch_btns:
		var bb: Button = item["btn"]
		bb.visible = show_btns
		if show_btns:
			bb.disabled = not GameState.can_afford(btn_cost)


## 按当前选中建筑重建"定型 / 改造"按钮：未定型满级塔 = 定型；已定型 + 有改造车间 = 改造
func _rebuild_branch_buttons() -> void:
	for c in _branch_box.get_children():
		_branch_box.remove_child(c)
		c.queue_free()
	_branch_btns.clear()
	if _sel == null or not is_instance_valid(_sel):
		return

	var opts: Array = []
	var cost := 0.0
	var title := "定型"
	if _sel.can_branch():
		opts = _sel.branch_options()
		cost = _sel.branch_cost()
	elif _sel.can_retrofit():
		opts = _sel.retrofit_options()
		cost = _sel.retrofit_cost()
		title = "改造"
	for k in opts:
		var bdef: Dictionary = GameConfig.build_def(k)
		var bb := _mk_button("", 0.0, 32.0)
		bb.text = "%s： %s  %d金" % [title, bdef["name"], int(cost)]
		bb.tooltip_text = bdef["desc"]
		bb.add_theme_font_size_override("font_size", 13)
		bb.add_theme_color_override("font_color", bdef["color"])
		bb.pressed.connect(_on_branch_pressed.bind(k))
		_branch_box.add_child(bb)
		_branch_btns.append({"btn": bb, "kind": k})


func _on_branch_pressed(new_kind: int) -> void:
	if _sel == null or not is_instance_valid(_sel):
		return
	var done := false
	if _sel.can_branch():
		done = _sel.branch_to(new_kind)
	elif _sel.can_retrofit():
		done = _sel.retrofit_to(new_kind)
	if done:
		_on_building_selected(_sel)   # 定型 / 改造后按新类型重填属性文本


func _on_upgrade_pressed() -> void:
	if _sel == null or not is_instance_valid(_sel):
		return
	if _sel.upgrade():
		_on_building_selected(_sel)   # 升级后按新等级重填属性文本


func _on_demolish_pressed() -> void:
	if _sel == null or not is_instance_valid(_sel):
		return
	_sel.demolish()


# ============================================================
#  提示与结算
# ============================================================
func _build_toast() -> void:
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -220.0
	_toast.offset_right = 220.0
	_toast.offset_top = 96.0
	_toast.offset_bottom = 126.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", GameConfig.C_BAD)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)

	var brand := Label.new()
	brand.text = "PRISM KEEP"
	brand.add_theme_font_size_override("font_size", 13)
	brand.add_theme_color_override("font_color",
			Color(GameConfig.C_TEXT_DIM.r, GameConfig.C_TEXT_DIM.g, GameConfig.C_TEXT_DIM.b, 0.75))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(brand)

	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 52)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_result_label)

	_result_sub = Label.new()
	_result_sub.add_theme_font_size_override("font_size", 17)
	_result_sub.add_theme_color_override("font_color", GameConfig.C_TEXT_DIM)
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_result_sub)

	var btn := _mk_button("再来一局", 200.0, 52.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_restart)
	vb.add_child(btn)


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ============================================================
#  信号接线
# ============================================================
func _wire() -> void:
	GameState.gold_changed.connect(_on_gold)
	GameState.base_changed.connect(_on_base)
	GameState.wave_changed.connect(_on_wave)
	GameState.build_mode_changed.connect(_refresh_build_buttons)
	GameState.notice.connect(_on_notice)
	GameState.building_selected.connect(_on_building_selected)
	GameState.game_finished.connect(_on_finished)
	GameState.skill_changed.connect(_on_skill_changed)
	GameState.retool_menu_toggled.connect(_on_retool_menu)

	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm != null:
		wm.prep_tick.connect(_on_prep)
		wm.wave_started.connect(_on_wave_started)


func _on_gold(value: float) -> void:
	_gold_label.text = "金币  %d" % int(value)


func _on_base(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	var p := 1.0
	if max_hp > 0.0:
		p = clampf(hp / max_hp, 0.0, 1.0)
	var c: Color = GameConfig.C_OK
	if p <= 0.25:
		c = GameConfig.C_BAD
	elif p <= 0.55:
		c = Color(1.0, 0.78, 0.28)
	_hp_fill.bg_color = c


func _on_wave(wave: int, total: int) -> void:
	_wave_label.text = "波次  %d / %d" % [wave, total]


func _on_prep(left: float) -> void:
	var s := int(ceil(left))
	if s == _last_prep:
		return
	_last_prep = s
	if s > 0:
		_next_btn.disabled = false
		_next_btn.text = "下一波  %d 秒（点击提前）" % s
	else:
		_next_btn.disabled = true
		_next_btn.text = "敌人来袭"


func _on_wave_started(w: int) -> void:
	_last_prep = -999
	_next_btn.disabled = true
	_next_btn.text = "第 %d 波 进行中" % w


func _on_notice(text: String) -> void:
	_toast.text = text
	_toast_t = 1.6
	_toast.modulate.a = 1.0


func _on_finished(win: bool) -> void:
	_overlay.visible = true
	if win:
		_result_label.text = "防守成功"
		_result_label.add_theme_color_override("font_color", GameConfig.C_OK)
		_result_sub.text = "挡住了全部 %d 波敌人" % GameState.total_waves
	else:
		_result_label.text = "大本营失守"
		_result_label.add_theme_color_override("font_color", GameConfig.C_BAD)
		_result_sub.text = "坚持到了第 %d 波" % GameState.wave
