extends Node2D
## 岩浆池：熔岩塔投掷落地后生成，覆盖半径内敌人持续施加灼烧
## 岩浆中的灼烧比例为基础灼烧 × LAVA_BURN_MUL（含技能点加成翻倍），离开后残留一段时间

var radius := 96.0
var time_left := 5.0
var _tick := 0.0
var _life := 0.0


func setup(pos: Vector2, r: float, t: float) -> void:
	position = pos
	radius = r
	time_left = t
	_life = t


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return

	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		var pct := (GameConfig.BURN_PCT + GameState.burn_bonus) * GameConfig.LAVA_BURN_MUL
		var r2 := radius * radius
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead:
				continue
			if global_position.distance_squared_to(e.global_position) <= r2:
				e.apply_burn(pct, GameConfig.LAVA_BURN_TIME)
	queue_redraw()


func _draw() -> void:
	var a := clampf(time_left / maxf(_life, 0.01), 0.0, 1.0)
	# 岩浆底面：暗红大圆 + 亮芯，消退时透明度下降
	draw_circle(Vector2.ZERO, radius, Color(0.50, 0.10, 0.08, 0.55 * a))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.88, 0.30, 0.10, 0.45 * a))
	draw_circle(Vector2.ZERO, radius * 0.40, Color(1.00, 0.55, 0.15, 0.35 * a))
	# 冒泡亮斑
	var t := Time.get_ticks_msec() * 0.001
	for i in 5:
		var ang := t * 0.8 + TAU * float(i) / 5.0
		var rr := radius * (0.3 + 0.35 * absf(sin(t * 1.5 + float(i) * 1.7)))
		draw_circle(Vector2(cos(ang), sin(ang)) * rr, 3.5,
				Color(1.0, 0.65, 0.20, 0.5 * a))
