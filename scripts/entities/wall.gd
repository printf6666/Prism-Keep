extends Building
## 围墙：无攻击、不可通行，用于把敌人逼向火力点或拖慢推进

func _ready() -> void:
	kind = GameConfig.Build.WALL
	is_wall = true
	tint = GameConfig.C_WALL
	max_hp = 420.0
	hp = max_hp


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 1.0
	var r := Rect2(-half, -half, half * 2.0, half * 2.0)

	draw_rect(r, col.darkened(0.55), true)
	draw_rect(r, col.darkened(0.15), false, 2.0)

	# 砖缝
	var seam := Color(col.r, col.g, col.b, 0.28)
	draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), seam, 1.5, true)
	draw_line(Vector2(-half, -half * 0.5), Vector2(0.0, -half * 0.5), seam, 1.5, true)
	draw_line(Vector2(0.0, half * 0.5), Vector2(half, half * 0.5), seam, 1.5, true)

	_draw_hp_bar(22.0, -half - 7.0)
