class_name Enemy
extends Node2D
## 敌人：纯几何体。沿流场走向大本营；前路被围墙挡住时改为拆墙。
## 圆形=普通 / 三角形=疾行 / 方形=重甲 / 五边形=Boss

const FX_SCENE := preload("res://scenes/fx/burst_fx.tscn")

const N8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var type := "grunt"
var shape := "circle"
var max_hp := 40.0
var hp := 40.0
var speed := 62.0
var damage := 8.0
var bounty := 4.0
var radius := 9.0
var color := Color(1, 0.4, 0.4)
var attack_interval := 1.0
var freeze_mul := 1.0
var breaker := false   # 能否强拆围墙（重甲 / Boss）

var dead := false

var _cell := Vector2i(-1, -1)
var _offset := Vector2.ZERO
var _face := 0.0
var _attack_cd := 0.0
var _hit := 0.0
var _wobble := 0.0
var freeze_left := 0.0
var slow_left := 0.0       # 减速剩余时间（冰暴等）
var slow_factor := 1.0     # 减速期间移速倍率（0.5 = 减半）
var burn_left := 0.0       # 灼烧剩余时间（喷火器 / 岩浆）
var burn_pct := 0.0        # 灼烧强度：每秒燃烧最大生命值的比例
var _burn_acc := 0.0       # 灼烧按整秒结算的累计器


func _ready() -> void:
	add_to_group("enemies")
	_wobble = randf() * TAU


func setup(d: Dictionary) -> void:
	type = d["type"]
	shape = d["shape"]
	max_hp = d["hp"]
	hp = max_hp
	speed = d["speed"]
	damage = d["dmg"]
	bounty = d["bounty"]
	radius = d["radius"]
	color = d["color"]
	attack_interval = d["interval"]
	freeze_mul = d.get("freeze_mul", 1.0)
	breaker = d.get("breaker", false)
	_offset = Vector2(randf_range(-0.26, 0.26), randf_range(-0.26, 0.26)) * GameConfig.CELL
	_attack_cd = randf() * attack_interval
	_cell = Board.cell_of(position)


func apply_freeze(duration: float) -> void:
	## 被冰冻：冻结期间无法移动与攻击，重复命中只取更长的冻结时间
	if dead:
		return
	freeze_left = maxf(freeze_left, duration * freeze_mul)
	queue_redraw()


func apply_slow(duration: float, factor: float) -> void:
	## 被减速：移速乘以 factor（0.5 = 减半）；重复命中取更久的时间与更强的减速
	if dead:
		return
	if slow_left <= 0.0:
		slow_factor = factor
	else:
		slow_factor = minf(slow_factor, factor)
	slow_left = maxf(slow_left, duration)
	queue_redraw()


func apply_burn(pct: float, duration: float) -> void:
	## 被点燃：每秒燃烧最大生命值的 pct；重复点燃取更强比例与更久时间
	if dead:
		return
	burn_pct = maxf(burn_pct, pct)
	burn_left = maxf(burn_left, duration)
	queue_redraw()


func _eff_speed() -> float:
	## 当前实际移速（减速期间乘以 slow_factor）
	return speed * (slow_factor if slow_left > 0.0 else 1.0)


func _process(delta: float) -> void:
	if dead:
		return

	_hit = maxf(0.0, _hit - delta * 4.0)

	# 灼烧：按整秒结算，每秒燃烧最大生命值的 burn_pct（冻结中仍持续燃烧）
	if burn_left > 0.0:
		burn_left = maxf(0.0, burn_left - delta)
		_burn_acc += delta
		if _burn_acc >= 1.0:
			_burn_acc -= 1.0
			take_damage(max_hp * burn_pct)
		queue_redraw()
		if dead:
			return

	# 冰冻中：原地冻结，不移动也不攻击
	if freeze_left > 0.0:
		freeze_left = maxf(0.0, freeze_left - delta)
		queue_redraw()
		return

	_attack_cd -= delta
	_wobble += delta * 6.0

	# 减速计时
	if slow_left > 0.0:
		slow_left = maxf(0.0, slow_left - delta)
		if slow_left <= 0.0:
			slow_factor = 1.0
			queue_redraw()

	var cell := Board.cell_of(global_position)
	_cell = cell

	# 1) 已抵达大本营：持续啃基地
	if Board.at_base(cell):
		_strike_base()
		queue_redraw()
		return

	# 2) 改造车间 / 路障嘲讽：身边 8 格有就停下来打（改造车间优先，所有敌人一视同仁）
	var bait = _adjacent_taunt(cell)
	if bait != null:
		_face_to(bait, delta)
		_strike(bait)
		queue_redraw()
		return

	# 3) 有路可走 → 沿“绕开建筑”的路线直扑大本营（首要目标永远是大本营）
	if Board.has_route(cell):
		var nxt := Board.next_cell(cell)
		if nxt.x < 0:
			_strike_base()
		else:
			_move_to(nxt, delta)
		queue_redraw()
		return

	# 4) 大本营被围死 → 优先拆炮塔，其次拆挡路的建筑（围墙只有重甲 / Boss 会强拆）
	var tower = _adjacent_tower(cell)
	if tower != null:
		_face_to(tower, delta)
		_strike(tower)
		queue_redraw()
		return

	var free_nxt := Board.next_cell_free(cell)
	if free_nxt.x < 0:
		queue_redraw()
		return

	var blocker = Board.get_building(free_nxt)
	if blocker != null and is_instance_valid(blocker):
		# 围墙挡路且自己不会强拆 → 尝试绕行，绕不开就原地等待（交给塔输出）
		if not blocker.is_wall or blocker.barricade or breaker:
			_face_to(blocker, delta)
			_strike(blocker)
			queue_redraw()
			return
		var alt := _sidestep(cell)
		if alt.x >= 0:
			_move_to(alt, delta)
		queue_redraw()
		return

	_move_to(free_nxt, delta)
	queue_redraw()


func _move_to(cell: Vector2i, delta: float) -> void:
	var target := Board.cell_to_world(cell) + _offset
	var to := target - global_position
	var d := to.length()
	if d > 0.5:
		var dir := to / d
		_face = lerp_angle(_face, dir.angle(), clampf(delta * 12.0, 0.0, 1.0))
		global_position += dir * _eff_speed() * delta


func _face_to(node: Node2D, delta: float) -> void:
	var to: Vector2 = node.global_position - global_position
	_face = lerp_angle(_face, to.angle(), clampf(delta * 10.0, 0.0, 1.0))


## 身边 8 格里最近的炮塔（被围死时的优先攻击目标）
func _adjacent_tower(cell: Vector2i):
	var best = null
	var best_d := 1.0e18
	for k in 8:
		var c: Vector2i = cell + N8[k]
		var b = Board.get_building(c)
		if b == null or not is_instance_valid(b):
			continue
		if not GameConfig.is_tower_kind(int(b.kind)):
			continue
		var d: float = global_position.distance_squared_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


## 身边 8 格里的嘲讽目标：改造车间（优先）> 路障
func _adjacent_taunt(cell: Vector2i):
	var barricade = null
	for k in 8:
		var c: Vector2i = cell + N8[k]
		var b = Board.get_building(c)
		if b == null or not is_instance_valid(b):
			continue
		if int(b.kind) == GameConfig.Build.RETOOL:
			return b
		if b.barricade and barricade == null:
			barricade = b
	return barricade


## 被围墙挡死且自己不强拆时的绕行：找 dist_free 更小的空邻格（不走建筑）
func _sidestep(cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = Board.dist_free[cell.y * Board.W + cell.x]
	for k in 8:
		var c: Vector2i = cell + N8[k]
		if not Board.in_bounds(c.x, c.y):
			continue
		if Board.get_building(c) != null:
			continue
		var d: float = Board.dist_free[c.y * Board.W + c.x]
		if d < best_d:
			best_d = d
			best = c
	return best


func _strike(target) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	target.take_damage(damage)


func _strike_base() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	GameState.damage_base(damage)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_hit = 1.0
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	GameState.add_gold(bounty)
	match type:
		"boss":
			GameState.add_skill_points(GameConfig.SP_BOSS)
		"tank":
			GameState.add_skill_points(GameConfig.SP_ELITE)
		_:
			GameState.add_skill_points(GameConfig.SP_MOB)
	var fx := FX_SCENE.instantiate() as BurstFx
	fx.position = position
	fx.tint = color
	fx.max_radius = radius * 2.2
	get_parent().add_child(fx)
	queue_free()


# ============================================================
#  绘制
# ============================================================
func _draw() -> void:
	var frozen := freeze_left > 0.0
	var col := color
	if _hit > 0.0:
		col = col.lerp(Color(1, 1, 1), clampf(_hit, 0.0, 0.85))
	if frozen:
		col = col.lerp(Color(0.72, 0.92, 1.0), 0.55)
	elif burn_left > 0.0:
		col = col.lerp(Color(1.0, 0.45, 0.10), 0.50)
	elif slow_left > 0.0:
		col = col.lerp(Color(0.62, 0.88, 1.0), 0.30)

	# 呼吸感：轻微缩放（冻结时定住）
	var s := 1.0
	if not frozen:
		s = 1.0 + sin(_wobble) * 0.05
	draw_set_transform(Vector2.ZERO, _face, Vector2(s, s))
	_draw_shape(radius * 1.22, col.darkened(0.55))
	_draw_shape(radius, col)
	if type == "boss":
		draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 16,
				Color(1, 1, 1, 0.55), 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 冰环：六边形冰壳
	if frozen:
		var a := clampf(freeze_left, 0.0, 0.4) / 0.4
		draw_arc(Vector2.ZERO, radius * 1.6, 0.0, TAU, 6,
				Color(0.72, 0.92, 1.0, 0.35 + a * 0.55), 1.5, true)

	# 血条
	if hp < max_hp:
		var w := maxf(radius * 2.2, 14.0)
		var y := -radius - 9.0
		var p := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, y, w, 3.0), Color(0, 0, 0, 0.55), true)
		draw_rect(Rect2(-w * 0.5, y, w * p, 3.0),
				GameConfig.C_OK if p > 0.5 else GameConfig.C_BAD, true)


func _draw_shape(r: float, col: Color) -> void:
	match shape:
		"square":
			var a := r * 0.88
			draw_rect(Rect2(-a, -a, a * 2.0, a * 2.0), col, true)
		"triangle":
			draw_colored_polygon(PackedVector2Array([
				Vector2(r * 1.25, 0.0),
				Vector2(-r * 0.95, r * 0.98),
				Vector2(-r * 0.95, -r * 0.98),
			]), col)
		"pentagon":
			draw_colored_polygon(_ngon(5, r * 1.08), col)
		_:
			draw_circle(Vector2.ZERO, r, col)


func _ngon(n: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := -PI * 0.5 + TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts
