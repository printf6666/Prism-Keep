extends Node2D
## 岩浆池：熔岩塔投掷落地后生成，覆盖半径内敌人持续施加灼烧
## 岩浆中的灼烧比例为基础灼烧 × LAVA_BURN_MUL（含技能点加成翻倍），离开后残留一段时间

var radius := 96.0
var time_left := 5.0
var _tick := 0.0
var _life := 0.0
var _pct := -1.0        # >=0 时直接使用该灼烧比例（核辐射），否则按岩浆公式（基础 × 2 + 加成翻倍）
var _tint := Color(0)   # a > 0 时使用自定义配色（核辐射绿），否则默认岩浆红
var is_lava := true     # 是否为熔岩岩浆（核辐射不是；水深火热只认岩浆）


func setup(pos: Vector2, r: float, t: float, pct := -1.0, tint := Color(0), lava := true) -> void:
	position = pos
	radius = r
	time_left = t
	_life = t
	_pct = pct
	_tint = tint
	is_lava = lava


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return

	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		var pct: float = _pct if _pct >= 0.0 \
				else (GameConfig.BURN_PCT + GameState.burn_bonus) * GameConfig.LAVA_BURN_MUL
		var r2 := radius * radius
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead:
				continue
			if global_position.distance_squared_to(e.global_position) <= r2:
				e.apply_burn(pct, GameConfig.LAVA_BURN_TIME)
				if is_lava:
					e.lava_stamp = Time.get_ticks_msec()   # 盖章：水深火热的"身处岩浆"凭据
	queue_redraw()


func _draw() -> void:
	var a := clampf(time_left / maxf(_life, 0.01), 0.0, 1.0)
	if _tint.a > 0.0:
		# 核辐射（绿）：三层绿晕 + 辐射环 + 冒泡亮斑
		var g := _tint
		draw_circle(Vector2.ZERO, radius, Color(g.r, g.g, g.b, 0.28 * a))
		draw_circle(Vector2.ZERO, radius * 0.72, Color(g.r * 1.15, g.g * 1.15, g.b * 0.55, 0.30 * a))
		draw_circle(Vector2.ZERO, radius * 0.42, Color(0.65, 0.95, 0.30, 0.30 * a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(g.r, g.g, g.b, 0.50 * a), 2.0, true)
		var t := Time.get_ticks_msec() * 0.001
		for i in 6:
			var ang := t * 0.7 + TAU * float(i) / 6.0
			var rr := radius * (0.25 + 0.4 * absf(sin(t * 1.3 + float(i) * 1.9)))
			draw_circle(Vector2(cos(ang), sin(ang)) * rr, 3.5,
					Color(0.70, 1.00, 0.35, 0.5 * a))
		return

	# 岩浆（默认红配色）
	draw_circle(Vector2.ZERO, radius, Color(0.50, 0.10, 0.08, 0.55 * a))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.88, 0.30, 0.10, 0.45 * a))
	draw_circle(Vector2.ZERO, radius * 0.40, Color(1.00, 0.55, 0.15, 0.35 * a))
	var t2 := Time.get_ticks_msec() * 0.001
	for i in 5:
		var ang := t2 * 0.8 + TAU * float(i) / 5.0
		var rr := radius * (0.3 + 0.35 * absf(sin(t2 * 1.5 + float(i) * 1.7)))
		draw_circle(Vector2(cos(ang), sin(ang)) * rr, 3.5,
				Color(1.0, 0.65, 0.20, 0.5 * a))
