extends Building
## 围墙 / 路障：无攻击、不可通行（BuildController 在 add_child 前设置 barricade）
##   · 围墙：被动阻挡，普通敌人不会攻击（重甲 / Boss 可强拆）
##   · 路障：嘲讽，所有敌人路过都会攻击它；寻路时被当成空地（见 Board._blocks_path）
## 两者均可升级至 3 级后分支定型：
##   · 城墙 → 绝对领域（主动代 5×5 内的塔承伤 + 塔免伤 5%）/ 记忆之石（每秒回 2 血）
##   · 路障 → 龟壳（每个攻击者 +5% 免伤，上限 50%）/ 荆棘（受击反弹附近敌人 0.5% 最大生命值）

var turtle := false      # 龟壳：按攻击者数量免伤
var thorns := false      # 荆棘：受击反弹
var memory := false      # 记忆之石：每秒回血
var _attackers := {}     # 敌人 -> 最后攻击时间（龟壳计层，超时自动失效）


func _ready() -> void:
	kind = GameConfig.Build.BARRICADE if barricade else GameConfig.Build.WALL
	is_wall = true
	tint = GameConfig.C_BARRICADE if barricade else GameConfig.C_WALL
	max_hp = (700.0 if barricade else 420.0) * GameState.wall_hp_mul
	hp = max_hp
	max_level = GameConfig.MAX_LEVEL


# ============================================================
#  满级分支（城墙 / 路障各二选一）
# ============================================================
func can_branch() -> bool:
	return level >= max_level and (kind == GameConfig.Build.WALL or kind == GameConfig.Build.BARRICADE)


func branch_options() -> Array:
	if kind == GameConfig.Build.WALL:
		return [GameConfig.Build.WALL_DOMAIN, GameConfig.Build.WALL_MEMORY]
	return [GameConfig.Build.BARRICADE_TURTLE, GameConfig.Build.BARRICADE_THORNS]


func branch_cost() -> float:
	return GameConfig.WALL_BRANCH_COST if kind == GameConfig.Build.WALL \
			else GameConfig.BARRICADE_BRANCH_COST


func branch_to(new_kind: int) -> bool:
	## 二选一定型：改 kind / 配色 / 机制并封顶，之后不可再升级
	if not can_branch():
		return false
	if not branch_options().has(new_kind):
		return false
	if not GameState.try_spend(branch_cost()):
		return false

	invested += branch_cost()
	max_level = level
	_apply_branch(new_kind)
	return true


func _apply_branch(new_kind: int) -> void:
	kind = new_kind
	match new_kind:
		GameConfig.Build.WALL_DOMAIN:
			tint = GameConfig.C_WALL_DOMAIN
			domain = true
		GameConfig.Build.WALL_MEMORY:
			tint = GameConfig.C_WALL_MEMORY
			memory = true
		GameConfig.Build.BARRICADE_TURTLE:
			tint = GameConfig.C_WALL_TURTLE
			turtle = true
		GameConfig.Build.BARRICADE_THORNS:
			tint = GameConfig.C_WALL_THORNS
			thorns = true
	_up_pulse = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	# 记忆之石：每秒恢复 2 点生命
	if memory and hp > 0.0 and hp < max_hp:
		hp = minf(hp + GameConfig.MEMORY_REGEN * delta, max_hp)
		queue_redraw()
	# 龟壳：攻击者超过 2.5 秒未攻击则不再计层
	if turtle and not _attackers.is_empty():
		var now := Time.get_ticks_msec() * 0.001
		for k in _attackers.keys():
			if now - _attackers[k] > 2.5:
				_attackers.erase(k)


func take_damage(amount: float, attacker = null) -> void:
	if hp <= 0.0:
		return
	if turtle and attacker != null:
		_attackers[attacker] = Time.get_ticks_msec() * 0.001
		amount *= 1.0 - minf(GameConfig.TURTLE_CAP, GameConfig.TURTLE_REDUCTION * _attackers.size())
	if thorns:
		_thorns_reflect()
	super.take_damage(amount, attacker)


## 荆棘：对附近敌人反弹其最大生命值 0.5% 的伤害
func _thorns_reflect() -> void:
	var r2 := GameConfig.THORNS_RADIUS * GameConfig.THORNS_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= r2:
			e.take_damage(e.max_hp * GameConfig.THORNS_PCT)


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

	# 分支标记
	match kind:
		GameConfig.Build.WALL_DOMAIN:
			draw_arc(Vector2.ZERO, half - 4.0, 0.0, TAU, 20, col.lightened(0.35), 2.0, true)
			draw_circle(Vector2.ZERO, 3.0, col.lightened(0.5))
		GameConfig.Build.WALL_MEMORY:
			draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), col.lightened(0.45), 2.5, true)
			draw_line(Vector2(0.0, -5.0), Vector2(0.0, 5.0), col.lightened(0.45), 2.5, true)
		GameConfig.Build.BARRICADE_TURTLE:
			draw_arc(Vector2.ZERO, half - 4.0, 0.0, TAU, 6, col.lightened(0.35), 2.0, true)
		GameConfig.Build.BARRICADE_THORNS:
			for i in 4:
				var a := TAU * float(i) / 4.0 + PI * 0.25
				var d := Vector2(cos(a), sin(a))
				draw_colored_polygon(PackedVector2Array([
					d * (half + 3.0), d.rotated(0.4) * (half - 3.0), d.rotated(-0.4) * (half - 3.0),
				]), col.lightened(0.3))

	_draw_hp_bar(22.0, -half - 7.0)
