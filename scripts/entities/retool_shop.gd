extends Building
## 改造车间：5×5 功能建筑，无攻击、易被敌人攻击
##   · 靠近按 I：用技能点购买全局加成（塔攻击 / 墙体血量 / 金矿产量）
##   · 选中已定型的塔：详情面板可付费改为另一分支

var _spin := 0.0


func _ready() -> void:
	footprint = Vector2i(5, 5)
	kind = GameConfig.Build.RETOOL
	tint = GameConfig.C_RETOOL
	max_hp = 320.0
	hp = max_hp


func _process(delta: float) -> void:
	super._process(delta)
	_spin += delta * 1.2
	queue_redraw()


func _draw() -> void:
	var col := _body_color(tint)
	var h := footprint.x * GameConfig.CELL * 0.5 - 3.0

	# 大底座平台
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(0.16, 0.12, 0.22), true)
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), col.darkened(0.25), false, 2.0)

	# 5×5 分格线
	var seam := Color(col.r, col.g, col.b, 0.16)
	for i in range(1, footprint.x):
		var off := -h + float(i) * GameConfig.CELL
		draw_line(Vector2(off, -h), Vector2(off, h), seam, 1.0, true)
		draw_line(Vector2(-h, off), Vector2(h, off), seam, 1.0, true)

	# 中央齿轮：外圈齿 + 圆环 + 中轴
	var teeth := 8
	var r_out := 15.0
	for i in teeth:
		var a := _spin + TAU * float(i) / float(teeth)
		var d := Vector2(cos(a), sin(a))
		draw_rect(Rect2(d * (r_out - 3.0) - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), col)
	draw_arc(Vector2.ZERO, r_out - 3.5, 0.0, TAU, 28, col, 3.0, true)
	draw_circle(Vector2.ZERO, 5.5, col.darkened(0.3))
	draw_circle(Vector2.ZERO, 2.6, col.lightened(0.5))

	_draw_hp_bar(60.0, -h - 8.0)
	super._draw()
