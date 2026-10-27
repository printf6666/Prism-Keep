extends Building
## 金矿：周期性产出金币，产出瞬间有一圈脉冲反馈

var interval := 2.0
var income := 3.0

var _t := 0.0
var _pulse := 0.0


func _ready() -> void:
	kind = GameConfig.Build.MINE
	tint = GameConfig.C_MINE
	max_hp = 220.0
	hp = max_hp
	_t = interval * randf_range(0.4, 1.0)


func _process(delta: float) -> void:
	super._process(delta)
	_pulse = maxf(0.0, _pulse - delta * 2.2)

	_t -= delta
	if _t <= 0.0:
		_t = interval
		_pulse = 1.0
		GameState.add_gold(income + GameState.mine_income_bonus)

	queue_redraw()


func _ngon(n: int, r: float, phase := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := phase + TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 4.0

	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.22, 0.18, 0.08), true)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.25), false, 2.0)

	# 六边形矿体
	var hex := _ngon(6, 10.0, -PI * 0.5)
	draw_colored_polygon(hex, col.darkened(0.25))
	var outline := hex.duplicate()
	outline.append(hex[0])
	draw_polyline(outline, col, 2.0, true)

	# 产出脉冲
	if _pulse > 0.0:
		var r := 10.0 + (1.0 - _pulse) * 12.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24,
				Color(col.r, col.g, col.b, _pulse * 0.8), 2.0, true)
	draw_circle(Vector2.ZERO, 3.0 + _pulse * 2.0, col.lightened(0.5))

	_draw_hp_bar(24.0, -half - 8.0)
