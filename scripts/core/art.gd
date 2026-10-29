class_name Art
extends RefCounted
## 纯代码美术：把几何形状光栅化成 ImageTexture，供 UI 图标使用。
## 游戏内的建筑/敌人则直接用 CanvasItem 的 _draw 绘制，不需要任何图片文件。

const SRC := 64   # 先按 64x64 光栅化，再缩放，得到近似抗锯齿的边


static func build_icon(kind: int, color: Color, out_size := 28) -> ImageTexture:
	var img := Image.create_empty(SRC, SRC, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match kind:
		GameConfig.Build.TOWER:
			# 底座方块 + 上方三角炮塔
			_fill(img, _rect(0.16, 0.56, 0.84, 0.84), color.darkened(0.15))
			_fill(img, [Vector2(0.5, 0.12), Vector2(0.88, 0.56), Vector2(0.12, 0.56)], color)
		GameConfig.Build.MINE:
			# 六边形 + 中心镂空
			var hex := _ngon(6, 0.42, 0.5, 0.5, -PI * 0.5)
			_fill(img, hex, color)
			_fill(img, _ngon(6, 0.17, 0.5, 0.5, -PI * 0.5), Color(0, 0, 0, 0))
		GameConfig.Build.WALL:
			# 带砖缝的墙体
			_fill(img, _rect(0.12, 0.30, 0.88, 0.72), color)
			_fill(img, _rect(0.12, 0.47, 0.88, 0.51), Color(0, 0, 0, 0.45))
			_fill(img, _rect(0.46, 0.30, 0.52, 0.47), Color(0, 0, 0, 0.45))
		GameConfig.Build.FROST:
			# 菱形冰晶 + 内部镂空
			_fill(img, [Vector2(0.5, 0.08), Vector2(0.84, 0.5), Vector2(0.5, 0.92), Vector2(0.16, 0.5)], color)
			_fill(img, [Vector2(0.5, 0.34), Vector2(0.66, 0.5), Vector2(0.5, 0.66), Vector2(0.34, 0.5)], Color(0, 0, 0, 0))
		GameConfig.Build.BARRICADE:
			# 路障：斜纹警示板 + 外撇支腿 + 底杆
			var dark: Color = color.darkened(0.45)
			_fill(img, _rect(0.12, 0.30, 0.88, 0.52), color)
			_fill(img, [Vector2(0.30, 0.30), Vector2(0.42, 0.30), Vector2(0.30, 0.52), Vector2(0.18, 0.52)], dark)
			_fill(img, [Vector2(0.62, 0.30), Vector2(0.74, 0.30), Vector2(0.62, 0.52), Vector2(0.50, 0.52)], dark)
			_fill(img, [Vector2(0.22, 0.52), Vector2(0.32, 0.52), Vector2(0.26, 0.84), Vector2(0.16, 0.84)], dark)
			_fill(img, [Vector2(0.68, 0.52), Vector2(0.78, 0.52), Vector2(0.84, 0.84), Vector2(0.74, 0.84)], dark)
			_fill(img, _rect(0.12, 0.80, 0.88, 0.86), dark)
		GameConfig.Build.CANNON:
			# 炮塔：圆形炮座 + 斜置厚重炮身 + 炮口制退器
			_fill(img, _ngon(8, 0.24, 0.42, 0.64), color.darkened(0.15))
			_fill(img, _ngon(8, 0.10, 0.42, 0.64), Color(0, 0, 0, 0))
			_fill(img, [Vector2(0.47, 0.69), Vector2(0.72, 0.44), Vector2(0.62, 0.34), Vector2(0.37, 0.59)], color)
			_fill(img, [Vector2(0.657, 0.403), Vector2(0.707, 0.453), Vector2(0.522, 0.338), Vector2(0.572, 0.288)], color.darkened(0.30))
		GameConfig.Build.RETOOL:
			# 改造车间：齿轮
			_fill(img, _ngon(8, 0.28, 0.5, 0.5), color)
			_fill(img, _rect(0.42, 0.08, 0.58, 0.22), color)
			_fill(img, _rect(0.42, 0.78, 0.58, 0.92), color)
			_fill(img, _rect(0.08, 0.42, 0.22, 0.58), color)
			_fill(img, _rect(0.78, 0.42, 0.92, 0.58), color)
			_fill(img, _ngon(8, 0.11, 0.5, 0.5), Color(0, 0, 0, 0))
		GameConfig.Build.FLAME:
			# 喷火器：燃料罐 + 喷管 + 扇形火舌
			var dark: Color = color.darkened(0.35)
			_fill(img, _rect(0.10, 0.44, 0.40, 0.80), color.darkened(0.15))
			_fill(img, _rect(0.10, 0.44, 0.40, 0.54), dark)
			_fill(img, _rect(0.40, 0.56, 0.64, 0.64), dark)
			_fill(img, [Vector2(0.60, 0.50), Vector2(0.94, 0.34), Vector2(0.86, 0.70)], color)
			_fill(img, [Vector2(0.60, 0.56), Vector2(0.84, 0.44), Vector2(0.78, 0.64)], Color(1.0, 0.8, 0.3))
			_fill(img, [Vector2(0.62, 0.58), Vector2(0.72, 0.52), Vector2(0.70, 0.62)], Color(1, 1, 0.85))
		GameConfig.Build.DEATH:
			# 死神：骷髅
			var bone := Color(0.88, 0.87, 0.82)
			_fill(img, _ngon(8, 0.28, 0.5, 0.40), bone)
			_fill(img, _rect(0.36, 0.58, 0.64, 0.70), bone)
			_fill(img, _rect(0.38, 0.32, 0.46, 0.44), color)
			_fill(img, _rect(0.54, 0.32, 0.62, 0.44), color)
			_fill(img, [Vector2(0.5, 0.46), Vector2(0.44, 0.54), Vector2(0.56, 0.54)], color)
			_fill(img, _rect(0.47, 0.58, 0.50, 0.70), color)
			_fill(img, _rect(0.55, 0.58, 0.58, 0.70), color)

	img.resize(out_size, out_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func _rect(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]


static func _ngon(n: int, r: float, cx: float, cy: float, phase := 0.0) -> Array:
	var pts: Array = []
	for i in n:
		var a := phase + TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts


static func _fill(img: Image, poly: Array, color: Color) -> void:
	## 逐像素判断是否落在多边形内（64x64 规模，开销可忽略）
	var n := poly.size()
	var pts: Array = []
	for p in poly:
		pts.append(Vector2(p.x * SRC, p.y * SRC))

	for y in SRC:
		for x in SRC:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var inside := false
			var j := n - 1
			for i in n:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[j]
				if ((a.y > py) != (b.y > py)) \
						and (px < (b.x - a.x) * (py - a.y) / (b.y - a.y) + a.x):
					inside = not inside
				j = i
			if inside:
				img.set_pixel(x, y, color)
