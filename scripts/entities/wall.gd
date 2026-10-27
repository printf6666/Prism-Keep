extends Building
## 围墙 / 路障：无攻击、不可通行（BuildController 在 add_child 前设置 barricade）
##   · 围墙：被动阻挡，普通敌人不会攻击（重甲 / Boss 可强拆）
##   · 路障：嘲讽，所有敌人路过都会攻击它，血量更高，替塔吸收火力


func _ready() -> void:
	kind = GameConfig.Build.BARRICADE if barricade else GameConfig.Build.WALL
	is_wall = true
	tint = GameConfig.C_BARRICADE if barricade else GameConfig.C_WALL
	max_hp = (700.0 if barricade else 420.0) * GameState.wall_hp_mul
	hp = max_hp


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 1.0
	var r := Rect2(-half, -half, half * 2.0, half * 2.0)

	draw_rect(r, col.darkened(0.55), true)
	draw_rect(r, col.darkened(0.15), false, 2.0)

	if barricade:
		# 路障：斜向警示条纹
		var stripe := Color(col.r, col.g, col.b, 0.55)
		for i in range(-3, 4):
			var d := float(i) * 9.0
			draw_line(Vector2(-half + maxf(d, 0.0), -half - minf(d, 0.0)),
					Vector2(half + minf(d, 0.0), half - maxf(d, 0.0)), stripe, 4.0, true)
	else:
		# 围墙：砖缝
		var seam := Color(col.r, col.g, col.b, 0.28)
		draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), seam, 1.5, true)
		draw_line(Vector2(-half, -half * 0.5), Vector2(0.0, -half * 0.5), seam, 1.5, true)
		draw_line(Vector2(0.0, half * 0.5), Vector2(half, half * 0.5), seam, 1.5, true)

	_draw_hp_bar(22.0, -half - 7.0)
