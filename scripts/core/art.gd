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
