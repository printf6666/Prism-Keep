class_name Enemy
extends Node2D
## 敌人：纯几何体。沿流场走向大本营；前路被围墙挡住时改为拆墙。
## 路障对小怪来说算“空地”：不会让它改道，但走到跟前仍然会被挡住并停下来拆它。
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
var _aggro = null           # 当前锁定的仇恨目标（建筑）
var _aggro_score := -1.0e18 # 锁定目标的仇恨分
var _aggro_scan_cd := 0.0   # 仇恨扫描节流

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
var dire := false          # 水深火热：减速 × 岩浆同时生效 → 负面翻倍 + 受伤 ×3
var lava_stamp := -100000  # 最近一次身处岩浆的时间戳（岩浆池每 0.5s 盖章）
var burn_source = null     # 点燃来源（灼烧击杀归属，觉醒养成）
var broken_left := 0.0     # 破甲剩余时间（箭塔觉醒）：受到的伤害 +25%
var armor_left := 0.0      # 召唤物落地减伤剩余时间
var armor_mul := 1.0       # 减伤期间受伤倍率
var last_attacker = null   # 最近一次攻击来源（觉醒击杀归属）
var _skill := ""           # Boss 技能（空 = 无）
var _enraged := false
var _summon_cd := 0.0
var _shield_cd := 0.0
var _shield_left := 0.0
var _corrode_tick := 0.0
var _split_on_death := false  # 分裂标记：死亡时再裂成两只小怪


func _ready() -> void:
	add_to_group("enemies")
	_wobble = randf() * TAU


func setup(d: Dictionary) -> void:
	type = d["type"]
	shape = d["shape"]
	max_hp = d["hp"]
	speed = d["speed"]
	damage = d["dmg"]
	bounty = d["bounty"]
	radius = d["radius"]
	color = d["color"]
	attack_interval = d["interval"]
	freeze_mul = d.get("freeze_mul", 1.0)
	_skill = d.get("skill", "")
	if _skill == "final":
		max_hp *= 2.0   # 终焉魔王：血量 ×2
	hp = max_hp
	_offset = Vector2(randf_range(-0.26, 0.26), randf_range(-0.26, 0.26)) * GameConfig.CELL
	_attack_cd = randf() * attack_interval
	_cell = Board.cell_of(position)


func apply_freeze(duration: float) -> void:
	## 被冰冻：冻结期间无法移动与攻击，重复命中只取更长的冻结时间
	if dead:
		return
	if _freeze_immune():
		return
	freeze_left = maxf(freeze_left, duration * freeze_mul)
	queue_redraw()


func apply_slow(duration: float, factor: float) -> void:
	## 被减速：移速乘以 factor（0.5 = 减半）；重复命中取更久的时间与更强的减速
	if dead or _skill == "iceskin":
		return
	if slow_left <= 0.0:
		slow_factor = factor
	else:
		slow_factor = minf(slow_factor, factor)
	slow_left = maxf(slow_left, duration)
	queue_redraw()


func apply_armor(mul: float, duration: float) -> void:
	## 召唤物落地保护：受伤 × mul（0.5 = 减半），持续 duration 秒
	if dead:
		return
	armor_mul = mul
	armor_left = maxf(armor_left, duration)
	queue_redraw()


func apply_break(duration: float) -> void:
	## 被破甲（箭塔觉醒）：受到的所有伤害 +25%
	if dead:
		return
	broken_left = maxf(broken_left, duration)
	queue_redraw()


func apply_burn(pct: float, duration: float, source = null, extend := 0.0) -> void:
	## 被点燃：每秒燃烧最大生命值的 pct；重复点燃取更强比例与更久时间
	## extend：业火燎原觉醒的额外延长
	if dead:
		return
	burn_pct = maxf(burn_pct, pct)
	burn_left = maxf(burn_left, duration) + extend
	burn_source = source
	queue_redraw()


func _freeze_immune() -> bool:
	## 狂暴中的 Boss 与"冰肤"Boss 免疫冰冻
	if _skill == "iceskin":
		return true
	return (_skill == "enrage" or _skill == "warlord" or _skill == "final") and _enraged


func _eff_speed() -> float:
	## 当前实际移速（减速期间乘以 slow_factor；水深火热下减速翻倍；护盾期间 ×1.5）
	var f := slow_factor if slow_left > 0.0 else 1.0
	if dire:
		f *= 0.5
	if _shield_left > 0.0:
		f *= 1.5
	return speed * f


func _process(delta: float) -> void:
	if dead:
		return

	_hit = maxf(0.0, _hit - delta * 4.0)

	# 水深火热：被冰暴减速 且 身处岩浆（600ms 内盖过章）→ 触发，否则解除
	dire = GameState.has_dire_straits() and slow_left > 0.0 \
			and Time.get_ticks_msec() - lava_stamp < 600

	# Boss 技能：触发器与周期效果（召唤 / 护盾 / 腐蚀 / 狂暴）
	_process_skill(delta)

	# 灼烧：按整秒结算，每秒燃烧最大生命值的 burn_pct（冻结中仍持续燃烧）
	# 冰肤减半；水深火热翻倍；击杀归属点燃来源
	if burn_left > 0.0:
		burn_left = maxf(0.0, burn_left - delta)
		_burn_acc += delta
		if _burn_acc >= 1.0:
			_burn_acc -= 1.0
			var bmul := 1.0
			if _skill == "iceskin":
				bmul *= 0.5
			take_damage(max_hp * burn_pct * bmul * (2.0 if dire else 1.0), burn_source, true)
		queue_redraw()
		if dead:
			return

	# 破甲 / 落地减伤计时
	if broken_left > 0.0:
		broken_left = maxf(0.0, broken_left - delta)
	if armor_left > 0.0:
		armor_left = maxf(0.0, armor_left - delta)

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

	# 2) 仇恨扫描（0.5 秒节流）：锁定路径上仇恨值最高的建筑
	_aggro_scan_cd -= delta
	if _aggro_scan_cd <= 0.0:
		_aggro_scan_cd = 0.5
		_update_aggro(cell)
	if _aggro != null and not is_instance_valid(_aggro):
		_aggro = null

	# 3) 锁定目标相邻 → 停下攻击（绝对领域代伤照常生效）
	if _aggro != null:
		var tc: Vector2i = _aggro.cell
		if absi(cell.x - tc.x) <= 1 and absi(cell.y - tc.y) <= 1:
			var victim = _aggro
			if GameConfig.is_weapon_tower(int(victim.kind)):
				var dom = _domain_covering(victim.cell)
				if dom != null:
					victim = dom
			_face_to(victim, delta)
			_strike(victim)
			queue_redraw()
			return

	# 4) 有路可走 → 沿路行进；前方格为锁定目标或路障 → 就地攻击
	if Board.has_route(cell):
		var nxt := Board.next_cell(cell)
		if nxt.x < 0:
			_strike_base()
			queue_redraw()
			return
		var ahead = Board.get_building(nxt)
		if ahead != null and is_instance_valid(ahead) and (_aggro == ahead or ahead.barricade):
			_face_to(ahead, delta)
			_strike(ahead)
			queue_redraw()
			return
		_move_to(nxt, delta)
		queue_redraw()
		return

	# 5) 被围死：砸开突围方向上的建筑继续前进
	var free_nxt := Board.next_cell_free(cell)
	if free_nxt.x < 0:
		queue_redraw()
		return
	var blocker = Board.get_building(free_nxt)
	if blocker != null and is_instance_valid(blocker):
		_face_to(blocker, delta)
		_strike(blocker)
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


## 仇恨扫描：从自身格 BFS（≤ AGGRO_SCAN 步），建筑格可被锁定但不继续扩展
##（路障对寻路是空地，因此可穿过并继续量距离）。
## 仇恨分 = 类型权重 − 路径步数：距离越近仇恨越高，同距离按类型权重定序。
## 锁定后不改变目标，除非扫描到仇恨值更高的建筑（或锁定目标被摧毁）。
func _update_aggro(cell: Vector2i) -> void:
	var best = null
	var best_score := -1.0e18
	var lock_alive := _aggro != null and is_instance_valid(_aggro)
	var lock_score := -1.0e18

	var queue: Array[Vector2i] = [cell]
	var dist := {cell: 0}
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = dist[cur]

		if d > 0:
			var b = Board.get_building(cur)
			if b != null and is_instance_valid(b):
				var score: float = GameConfig.aggro_priority(int(b.kind)) - float(d)
				if lock_alive and b == _aggro:
					lock_score = score
				elif score > best_score:
					best_score = score
					best = b
				if Board._blocks_path(Board.idx(cur.x, cur.y)):
					continue   # 建筑格：可锁定但不穿越（路障例外，可继续量距离）

		if d >= GameConfig.AGGRO_SCAN:
			continue
		for k in 8:
			var nc: Vector2i = cur + N8[k]
			if not Board.in_bounds(nc.x, nc.y) or dist.has(nc):
				continue
			dist[nc] = d + 1
			queue.append(nc)

	# 锁定目标被摧毁 → 立即改锁扫描到的最高仇恨目标
	if not lock_alive:
		_aggro = best
		_aggro_score = best_score
		return
	# 扫描到仇恨值更高的建筑 → 换目标；否则保持锁定并刷新其仇恨分
	if best != null and best_score > lock_score + 0.0001:
		_aggro = best
		_aggro_score = best_score
	elif _aggro != null:
		_aggro_score = lock_score


## 覆盖某格的绝对领域城墙（领域内塔被攻击时代为承受）
func _domain_covering(c: Vector2i):
	for b in Board.buildings.values():
		if not is_instance_valid(b) or not b.domain:
			continue
		var wc: Vector2i = b.cell
		if absi(c.x - wc.x) <= 2 and absi(c.y - wc.y) <= 2:
			return b
	return null


## Boss 技能：触发器与周期效果（每个技能一个分支，数据来自 enemy_def 的 "skill"）
func _process_skill(delta: float) -> void:
	if _skill == "":
		return

	# 狂暴 / 战争领主 / 终焉魔王：血量 <60% 触发一次
	if not _enraged and max_hp > 0.0 and hp <= max_hp * 0.6 \
			and (_skill == "enrage" or _skill == "warlord" or _skill == "final"):
		_enraged = true
		attack_interval *= 0.5 if _skill == "enrage" else 0.66

	# 召唤尸潮 / 战争领主 / 终焉魔王：周期召唤
	if _skill == "summon" or _skill == "warlord" or _skill == "final":
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = 6.0 if _skill == "summon" else (10.0 if _skill == "warlord" else 8.0)
			_summon(3 if _skill == "summon" else 2)

	# 掩体护盾 / 终焉魔王：周期开盾（免伤 80%，移速 ×1.5）
	if _skill == "shield" or _skill == "final":
		if _shield_left > 0.0:
			_shield_left = maxf(0.0, _shield_left - delta)
		else:
			_shield_cd -= delta
			if _shield_cd <= 0.0:
				_shield_left = 4.0
				_shield_cd = 10.0 if _skill == "shield" else 12.0

	# 腐蚀光环：周围 3 格建筑每秒受 3% 自身最大生命值伤害
	if _skill == "corrode":
		_corrode_tick -= delta
		if _corrode_tick <= 0.0:
			_corrode_tick = 1.0
			var r2 := 96.0 * 96.0
			for b in Board.buildings.values():
				if is_instance_valid(b):
					if global_position.distance_squared_to(b.global_position) <= r2:
						b.take_damage(b.max_hp * 0.03, self)

	# EMP 脉冲：沉默 3 格内的武器塔 5 秒（同一塔 8 秒内不会重复触发）
	if _skill == "emp":
		_corrode_tick -= delta
		if _corrode_tick <= 0.0:
			_corrode_tick = 1.0
			var r2 := 96.0 * 96.0
			for b in Board.buildings.values():
				if is_instance_valid(b) and GameConfig.is_weapon_tower(int(b.kind)) \
						and b.silence_cd <= 0.0 \
						and global_position.distance_squared_to(b.global_position) <= r2:
					b.silence_left = 5.0
					b.silence_cd = 8.0


## 召唤尸潮：在身边召唤 n 只疾行怪，落地自带 3 秒减伤
func _summon(n: int) -> void:
	var scene := load("res://scenes/entities/enemy.tscn")
	for i in n:
		var e = scene.instantiate()
		e.position = global_position + Vector2(randf_range(-48.0, 48.0), randf_range(-48.0, 48.0))
		get_parent().add_child(e)
		e.setup(GameConfig.enemy_def("runner", GameState.wave))
		e.apply_armor(0.5, 3.0)


func _strike(target) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	target.take_damage(damage, self)


func _strike_base() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	GameState.damage_base(damage)


func take_damage(amount: float, _attacker = null, from_burn := false) -> void:
	if dead:
		return
	# 掩体护盾：免伤 80%
	if _shield_left > 0.0:
		amount *= 0.2
	# 召唤物落地减伤
	if armor_left > 0.0:
		amount *= armor_mul
	# 虚弱（水深火热）：受到的伤害翻三倍（灼烧本身已在结算时翻倍，不再叠加）
	if dire and not from_burn:
		amount *= 3.0
	# 破甲（箭塔觉醒）：受到的伤害 +25%
	if broken_left > 0.0:
		amount *= 1.25
	if _attacker != null:
		last_attacker = _attacker
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
	GameState.enemy_killed.emit(String(type))

	# 击杀归属（塔觉醒养成）
	if last_attacker != null and is_instance_valid(last_attacker) \
			and last_attacker.has_method("register_kill"):
		last_attacker.register_kill()

	# 极寒领域：冰冻中的敌人死亡时冰爆，冻结周围 2 格敌人 1 秒
	if freeze_left > 0.0 and last_attacker != null and is_instance_valid(last_attacker) \
			and last_attacker.get("awakened") \
			and GameConfig.awaken_family(int(last_attacker.kind)) == GameConfig.Build.FROST:
		var ir2 := 64.0 * 64.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead or e == self:
				continue
			if global_position.distance_squared_to(e.global_position) <= ir2:
				e.apply_freeze(1.0)

	# 分裂（第 40 波 Boss 技能）：死亡裂成 2 只重甲；重甲再裂成 2 只小怪（只裂两层）
	if _skill == "split" and type == "boss":
		_spawn_split("tank", max_hp * 0.6)
	if _split_on_death:
		_spawn_split("grunt", max_hp * 0.5)

	# 亡语沉默（第 90 波 Boss 技能）：死亡时全场武器塔沉默 6 秒
	if _skill == "wail":
		for b in Board.buildings.values():
			if is_instance_valid(b) and GameConfig.is_weapon_tower(int(b.kind)):
				b.silence_left = 6.0

	var fx := FX_SCENE.instantiate() as BurstFx
	fx.position = position
	fx.tint = color
	fx.max_radius = radius * 2.2
	get_parent().add_child(fx)
	queue_free()


## 分裂：在身边生成 2 只指定类型敌人（血量按比例继承）
func _spawn_split(t: String, hp: float) -> void:
	var scene := load("res://scenes/entities/enemy.tscn")
	for i in 2:
		var e = scene.instantiate()
		e.position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		get_parent().add_child(e)
		var d := GameConfig.enemy_def(t, GameState.wave)
		d["hp"] = hp
		e.setup(d)
		e._split_on_death = t == "tank"


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
	elif dire:
		col = col.lerp(Color(0.78, 0.30, 0.95), 0.40)
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

	# 掩体护盾：蓝白护盾环
	if _shield_left > 0.0:
		draw_arc(Vector2.ZERO, radius * 1.9, 0.0, TAU, 20,
				Color(0.6, 0.8, 1.0, 0.55), 2.0, true)

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
