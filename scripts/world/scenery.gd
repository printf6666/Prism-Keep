extends Node2D
## 末日废土背景装饰：弹坑 / 废墟瓦砾 / 地面裂缝 / 枯树 / 焦土 / 辐射区
## 纯装饰（不影响玩法）：每局随机生成一次，绘制时只画视口内的部分；
## 所有随机数在生成期烘焙进条目，绘制期不再随机，避免逐帧闪烁。

const COUNTS := {
	"crater": 34,
	"rubble": 54,
	"crack": 30,
	"tree": 26,
	"scorch": 42,
	"debris": 72,
	"radiation": 3,
}

var _items: Array = []
var _generated := false


func _ready() -> void:
	z_index = 0


func _process(_delta: float) -> void:
	# Board 的矿山在 main._ready 才生成，等它就绪后再布置装饰（避开矿点）
	if not _generated and Board.ores.size() > 0:
		_generate()
	queue_redraw()


func _generate() -> void:
	_generated = true
	var ws := GameConfig.world_size()
	var base_c := GameConfig.BASE_CELL + Vector2i.ONE
	for type in COUNTS:
		var n: int = COUNTS[type]
		var placed := 0
		var guard := 0
		while placed < n and guard < n * 40:
			guard += 1
			var pos := Vector2(randf_range(0.0, ws.x), randf_range(0.0, ws.y))
			var cell := Board.cell_of(pos)
			# 避开大本营周边，保持出生区域干净
			if maxi(absi(cell.x - base_c.x), absi(cell.y - base_c.y)) <= 5:
				continue
			# 避开矿山格附近，保持矿点标识清晰
			var near_ore := false
			for oc in Board.ore_cells():
				if absi(cell.x - oc.x) <= 1 and absi(cell.y - oc.y) <= 1:
					near_ore = true
					break
			if near_ore:
				continue

			var it := {"type": type, "pos": pos, "rot": randf_range(0.0, TAU),
					"s": randf_range(0.75, 1.35), "v": randf()}
			match type:
				"crack":
					it["pts"] = _gen_crack_pts(it)
				"scorch":
					it["poly"] = _gen_blob(8, 10.0, 22.0)
				"tree":
					it["segs"] = _gen_tree_segs(it)
				"rubble":
					it["offs"] = _gen_rubble_offs(it)
				"debris":
					it["offs"] = _gen_debris_offs(it)
				"radiation":
					it["r"] = randf_range(60.0, 110.0)
			_items.append(it)
			placed += 1


func _gen_crack_pts(it: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var dir := Vector2.RIGHT.rotated(it["rot"])
	var p := Vector2.ZERO
	for i in 6:
		dir = dir.rotated(randf_range(-0.55, 0.55))
		p += dir * randf_range(7.0, 13.0)
		pts.append(p)
	return pts


func _gen_blob(n: int, r_min: float, r_max: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * randf_range(r_min, r_max))
	return pts


func _gen_tree_segs(it: Dictionary) -> Array:
	var segs: Array = []
	var top := Vector2(randf_range(-3.0, 3.0), -randf_range(18.0, 26.0))
	segs.append([Vector2.ZERO, top])
	for b in 2 + int(randf() * 2.0):
		var from := top * randf_range(0.35, 0.9)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, -0.1)).normalized()
		segs.append([from, from + dir * randf_range(8.0, 15.0)])
	return segs


func _gen_rubble_offs(it: Dictionary) -> Array:
	var offs: Array = []
	var n := 3 + int(it["v"] * 3.0)
	for i in n:
		var a: float = TAU * float(i) / float(n) + it["rot"] * 2.0
		offs.append({"d": Vector2(cos(a), sin(a)) * (3.0 + it["v"] * 7.0),
				"sz": 3.0 + it["v"] * 4.0})
	return offs


func _gen_debris_offs(it: Dictionary) -> Array:
	var offs: Array = []
	for i in 6:
		offs.append({"d": Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)),
				"rust": randf() < 0.35})
	return offs


func _draw() -> void:
	var view := _view_rect()
	for it in _items:
		var p: Vector2 = it["pos"]
		if p.x < view.position.x - 120.0 or p.x > view.end.x + 120.0 \
				or p.y < view.position.y - 120.0 or p.y > view.end.y + 120.0:
			continue
		draw_set_transform(p, it["rot"], Vector2(it["s"], it["s"]))
		match it["type"]:
			"crater":
				_draw_crater(it)
			"rubble":
				_draw_rubble(it)
			"crack":
				_draw_crack(it)
			"tree":
				_draw_tree(it)
			"scorch":
				_draw_scorch(it)
			"debris":
				_draw_debris(it)
			"radiation":
				_draw_radiation(it)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_crater(it: Dictionary) -> void:
	var r: float = 13.0 + it["v"] * 16.0
	draw_circle(Vector2.ZERO, r, Color(0.046, 0.043, 0.037))
	draw_circle(Vector2.ZERO, r * 0.7, Color(0.033, 0.031, 0.027))
	draw_arc(Vector2.ZERO, r, PI * 0.1, PI * 0.95, 16, Color(0.155, 0.14, 0.115, 0.7), 2.0, true)
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + it["rot"] * 3.0
		draw_circle(Vector2(cos(a), sin(a)) * (r + 3.0), 1.6, Color(0.13, 0.12, 0.10))


func _draw_rubble(it: Dictionary) -> void:
	var base := Color(0.135, 0.13, 0.115)
	for o in it["offs"]:
		var sz: float = o["sz"]
		draw_rect(Rect2(o["d"] - Vector2(sz, sz) * 0.5, Vector2(sz * 1.4, sz)), base, true)
	draw_line(Vector2(-8.0, 2.0), Vector2(9.0, -3.0), Color(0.22, 0.15, 0.10), 1.2, true)


func _draw_crack(it: Dictionary) -> void:
	draw_polyline(it["pts"], Color(0.031, 0.029, 0.025), 1.6, true)


func _draw_tree(it: Dictionary) -> void:
	var col := Color(0.115, 0.098, 0.078)
	var segs: Array = it["segs"]
	for i in segs.size():
		var s: Array = segs[i]
		draw_line(s[0], s[1], col, 2.4 if i == 0 else 1.4, true)


func _draw_scorch(it: Dictionary) -> void:
	draw_colored_polygon(it["poly"], Color(0.042, 0.038, 0.032))


func _draw_debris(it: Dictionary) -> void:
	for o in it["offs"]:
		var c: Color = Color(0.20, 0.12, 0.07) if o["rust"] else Color(0.17, 0.16, 0.13)
		draw_circle(o["d"], 1.4, c)


func _draw_radiation(it: Dictionary) -> void:
	var r: float = it["r"]
	var g := Color(0.45, 0.70, 0.20)
	draw_circle(Vector2.ZERO, r, Color(0.22, 0.34, 0.10, 0.05))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(g.r, g.g, g.b, 0.12), 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 40, Color(g.r, g.g, g.b, 0.08), 1.5, true)
	draw_circle(Vector2.ZERO, 4.0, Color(g.r, g.g, g.b, 0.15))


func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(Vector2.ZERO, GameConfig.world_size())
	var inv := vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * vp.get_visible_rect().size
	return Rect2(a, b - a)
