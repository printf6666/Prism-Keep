extends Node2D
## 大本营：地图正中央的 2x2 核心，外圈环形血条实时反映剩余血量
## 玩家靠近时提示按 B 打开词条商店（用晶源购买全局词条）

var _t := 0.0
var _player_near := false


func _ready() -> void:
	position = GameConfig.base_center()
	z_index = 1
	GameState.base_changed.connect(_on_base_changed)


func _on_base_changed(_hp: float, _max_hp: float) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_player_near = _check_player_near()
	queue_redraw()


func _check_player_near() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return false
	var c := Board.cell_of(p.global_position)
	return c.x >= GameConfig.BASE_CELL.x - 1 and c.x <= GameConfig.BASE_CELL.x + GameConfig.BASE_SIZE \
			and c.y >= GameConfig.BASE_CELL.y - 1 and c.y <= GameConfig.BASE_CELL.y + GameConfig.BASE_SIZE


func _draw() -> void:
	var half := GameConfig.CELL * float(GameConfig.BASE_SIZE) * 0.5   # 32
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	var hp_p := 1.0
	if GameState.base_hp_max > 0.0:
		hp_p = clampf(GameState.base_hp / GameState.base_hp_max, 0.0, 1.0)

	var core := GameConfig.C_BASE
	var glow := Color(core.r, core.g, core.b, 0.10 + 0.06 * pulse)

	# 地面光环
	draw_circle(Vector2.ZERO, half * 1.9, glow)

	# 主体
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.08, 0.14, 0.20), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), core.darkened(0.2), false, 3.0)

	# 内部菱形
	var d := half * (0.52 + 0.05 * pulse)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0),
	]), Color(core.r, core.g, core.b, 0.85))
	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.85))

	# 环形血条
	var r := half * 1.45
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 1, 1, 0.10), 4.0, true)
	var hp_col: Color = GameConfig.C_OK
	if hp_p <= 0.25:
		hp_col = GameConfig.C_BAD
	elif hp_p <= 0.55:
		hp_col = Color(1.0, 0.78, 0.28)
	draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * hp_p, 64, hp_col, 4.0, true)

	# 靠近提示：按 B 打开词条商店（商店开着时不再提示）
	if _player_near and not GameState.affix_shop_open:
		var a := 0.55 + 0.35 * pulse
		draw_string(ThemeDB.fallback_font, Vector2(-90.0, -half - 18.0), "按 B 打开词条商店",
				HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(core.r, core.g, core.b, a))
