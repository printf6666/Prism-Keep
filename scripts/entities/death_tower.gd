extends Building
## 死神：超级武器，全图限一座
##   · 1~3 级：对 Boss 伤害 5% 起、每级 +5%；全图索敌，炮弹秒杀 10×10 内非 Boss 并留核辐射
##   · 3 级分支进化（3000 金）：
##       核弹井     —— 右键手动瞄准，3 分钟冷却；打击面积为初始死神的 6 倍，Boss 伤害 ×6
##       灵魂摆渡者 —— 保留自动开火；击杀收集灵魂（精英 2 / Boss 5 / 小怪 1），
##                     每 100 灵魂计 1 次释放（灵魂不消耗），右键自己释放全场冲击
##                     （20% 最大生命值起，按灵魂每多 100 +1%，对 Boss 上限 20%）

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var fire_interval := GameConfig.DEATH_INTERVAL
var souls := 0                # 灵魂摆渡者累计收集的灵魂（不消耗）
var _used_charges := 0        # 已用掉的释放次数（每 100 灵魂计 1 次）

var _cd := 4.0                # 开局延迟几秒再索敌
var _scan_cd := 0.0
var _target_pos := Vector2.INF
var _pulse := 0.0
var _aim := -PI * 0.5


func _ready() -> void:
	footprint = Vector2i(6, 6)
	kind = GameConfig.Build.DEATH
	tint = GameConfig.C_DEATH
	max_hp = 260.0
	hp = max_hp
	max_level = GameConfig.DEATH_MAX_LEVEL


func _on_upgraded() -> void:
	super._on_upgraded()
	_up_pulse = 1.0


## 当前等级对 Boss 的伤害比例（最大生命值）
func boss_pct() -> float:
	return GameConfig.DEATH_BOSS_DMG_PCT + GameConfig.DEATH_BOSS_DMG_STEP * float(level - 1)


# ============================================================
#  满级分支进化：核弹井 / 灵魂摆渡者
# ============================================================
func can_branch() -> bool:
	return level >= max_level and kind == GameConfig.Build.DEATH


func branch_options() -> Array:
	return [GameConfig.Build.DEATH_SILO, GameConfig.Build.DEATH_FERRY]


func branch_cost() -> float:
	return GameConfig.DEATH_BRANCH_COST


func branch_to(new_kind: int) -> bool:
	if not can_branch():
		return false
	if not branch_options().has(new_kind):
		return false
	if not GameState.try_spend(GameConfig.DEATH_BRANCH_COST):
		return false

	invested += GameConfig.DEATH_BRANCH_COST
	max_level = level
	_apply_branch(new_kind)
	_up_pulse = 1.0
	queue_redraw()
	return true


func _apply_branch(new_kind: int) -> void:
	kind = new_kind
	_target_pos = Vector2.INF
	match new_kind:
		GameConfig.Build.DEATH_SILO:
			tint = GameConfig.C_DEATH_SILO
			_cd = 0.0   # 建好即可手动发射一次
		GameConfig.Build.DEATH_FERRY:
			tint = GameConfig.C_DEATH_FERRY
			if not GameState.enemy_killed.is_connected(_on_enemy_killed):
				GameState.enemy_killed.connect(_on_enemy_killed)


func can_retrofit() -> bool:
	return kind != GameConfig.Build.DEATH and level >= max_level \
			and Board.has_kind(GameConfig.Build.RETOOL)


func retrofit_options() -> Array:
	var opts: Array = []
	for k in branch_options():
		if k != kind:
			opts.append(k)
	return opts


func retrofit_to(new_kind: int) -> bool:
	if not can_retrofit() or not retrofit_options().has(new_kind):
		return false
	if not GameState.try_spend(retrofit_cost()):
		return false
	invested += retrofit_cost()
	_apply_branch(new_kind)
	_up_pulse = 1.0
	queue_redraw()
	return true


# ============================================================
#  右键手动效果（核弹井瞄准 / 灵魂摆渡者释放）
# ============================================================
func try_manual_action(world_pos: Vector2) -> bool:
	if kind == GameConfig.Build.DEATH_SILO:
		if _cd > 0.0:
			GameState.notice.emit("核弹井冷却中（%d 秒）" % int(ceil(_cd)))
			return true
		_cd = GameConfig.SILO_COOLDOWN
		var r: float = GameConfig.DEATH_RADIUS * sqrt(GameConfig.SILO_AREA_MUL)
		_fire_shell(world_pos, r, GameConfig.DEATH_RADIATION_TIME,
				boss_pct() * GameConfig.SILO_BOSS_MUL)
		_aim = global_position.angle_to_point(world_pos)
		_pulse = 1.0
		GameState.notice.emit("核弹井已发射")
		return true

	if kind == GameConfig.Build.DEATH_FERRY:
		var c := Board.cell_of(world_pos)
		var on_self := c.x >= cell.x and c.x < cell.x + footprint.x \
				and c.y >= cell.y and c.y < cell.y + footprint.y
		if not on_self:
			return false
		if souls < GameConfig.FERRY_THRESHOLD or soul_charges() <= 0:
			GameState.notice.emit("可释放次数不足（灵魂 %d，可释放 %d 次）" % [souls, soul_charges()])
			return true
		soul_blast()
		return true

	return false


## 当前可释放次数：已累计的灵魂每 100 点计 1 次（灵魂不消耗，只消耗次数）
func soul_charges() -> int:
	return souls / GameConfig.FERRY_THRESHOLD - _used_charges


## 灵魂冲击：消耗 1 次释放次数（不消耗灵魂），全场敌人受最大生命值 20% 起
##（按当前灵魂每多 100 +1%，Boss 上限 20%）
func soul_blast() -> void:
	if soul_charges() <= 0:
		return
	var extra := (souls - GameConfig.FERRY_THRESHOLD) / 100
	var pct: float = GameConfig.FERRY_BASE_PCT + GameConfig.FERRY_STEP_PCT * float(extra)
	var boss_hit: float = minf(pct, GameConfig.FERRY_BOSS_CAP)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var p := boss_hit if String(e.type) == "boss" else pct
		e.take_damage(e.max_hp * p)
	_used_charges += 1
	_pulse = 1.0
	GameState.notice.emit("灵魂冲击：%d%% 最大生命值（剩余 %d 次）"
			% [int(round(pct * 100.0)), soul_charges()])


func _on_enemy_killed(t: String) -> void:
	match t:
		"boss":
			souls += GameConfig.FERRY_SOUL_BOSS
		"tank":
			souls += GameConfig.FERRY_SOUL_ELITE
		_:
			souls += GameConfig.FERRY_SOUL_MOB
	queue_redraw()


# ============================================================
#  灭世：改造车间技能，连射 10 颗巨型核弹
# ============================================================
func fire_apocalypse() -> void:
	var used: Array = []
	for i in GameConfig.APOCALYPSE_NUKES:
		var pos := _pick_apocalypse_target(used)
		used.append(pos)
		_fire_shell(pos, GameConfig.APOCALYPSE_RADIUS, GameConfig.APOCALYPSE_RAD_TIME,
				GameConfig.APOCALYPSE_BOSS_PCT, true)
	_pulse = 1.0
	GameState.notice.emit("灭世：10 颗巨型核弹已发射")


## 每颗核弹优先砸向未被覆盖的敌人最密集处；场上无敌人时随机落点
func _pick_apocalypse_target(used: Array) -> Vector2:
	var list := get_tree().get_nodes_in_group("enemies")
	var best_pos := Vector2.INF
	var best_n := 0
	var r2 := GameConfig.APOCALYPSE_RADIUS * GameConfig.APOCALYPSE_RADIUS
	for e in list:
		if e.dead:
			continue
		var covered := false
		for u in used:
			if e.global_position.distance_to(u) < GameConfig.APOCALYPSE_RADIUS * 0.8:
				covered = true
				break
		if covered:
			continue
		var n := 0
		for f in list:
			if f.dead:
				continue
			if e.global_position.distance_squared_to(f.global_position) <= r2:
				n += 1
		if n > best_n:
			best_n = n
			best_pos = e.global_position
	if best_pos == Vector2.INF:
		var ws := GameConfig.world_size()
		best_pos = Vector2(randf_range(0.0, ws.x), randf_range(0.0, ws.y))
	return best_pos


# ============================================================
#  运行
# ============================================================
func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	_scan_cd -= delta
	_pulse = maxf(0.0, _pulse - delta * 2.0)

	# 核弹井：纯手动瞄准，不自动索敌
	if kind == GameConfig.Build.DEATH_SILO:
		queue_redraw()
		return

	# 全图索敌：节流到 0.5 秒一次
	if _scan_cd <= 0.0:
		_scan_cd = 0.5
		_target_pos = _acquire_cluster_point()

	if _target_pos != Vector2.INF and _cd <= 0.0:
		_cd = fire_interval
		_pulse = 1.0
		_fire_shell(_target_pos, GameConfig.DEATH_RADIUS,
				GameConfig.DEATH_RADIATION_TIME, boss_pct())

	queue_redraw()


## 全图索敌：核弹覆盖范围内敌人最多的落点（无距离限制）
func _acquire_cluster_point() -> Vector2:
	var list := get_tree().get_nodes_in_group("enemies")
	var best_pos := Vector2.INF
	var best_n := 0
	var r2 := GameConfig.DEATH_RADIUS * GameConfig.DEATH_RADIUS
	for e in list:
		if e.dead:
			continue
		var n := 0
		for f in list:
			if f.dead:
				continue
			if e.global_position.distance_squared_to(f.global_position) <= r2:
				n += 1
		if n > best_n:
			best_n = n
			best_pos = e.global_position
	return best_pos


func _fire_shell(pos: Vector2, radius: float, rad_time: float, bpct: float,
		is_giant := false) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position
	p.setup_death(pos, GameConfig.DEATH_SHELL_SPEED, tint, radius, rad_time, bpct, is_giant)
	layer.add_child(p)


# ============================================================
#  绘制
# ============================================================
func _draw() -> void:
	var col := _body_color(tint)
	var h := footprint.x * GameConfig.CELL * 0.5 - 3.0

	# 大底座平台
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(0.10, 0.08, 0.14), true)
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), col.darkened(0.25), false, 2.0)

	# 6×6 分格线
	var seam := Color(col.r, col.g, col.b, 0.14)
	for i in range(1, footprint.x):
		var off := -h + float(i) * GameConfig.CELL
		draw_line(Vector2(off, -h), Vector2(off, h), seam, 1.0, true)
		draw_line(Vector2(-h, off), Vector2(h, off), seam, 1.0, true)

	# 兜帽下的骷髅：苍白头骨 + 双黑洞（放大版）
	draw_circle(Vector2.ZERO, 13.0, col.darkened(0.35))
	draw_circle(Vector2(0.0, -1.5), 9.0, Color(0.88, 0.87, 0.82))
	draw_circle(Vector2(-3.3, -2.2), 2.2, Color(0.06, 0.05, 0.08))
	draw_circle(Vector2(3.3, -2.2), 2.2, Color(0.06, 0.05, 0.08))
	draw_rect(Rect2(-2.4, 3.6, 4.8, 3.0), Color(0.88, 0.87, 0.82), true)

	# 就绪脉冲（核弹井冷却完毕 / 其他塔就绪）
	if _cd <= 0.0 and (kind == GameConfig.Build.DEATH_SILO or _target_pos != Vector2.INF):
		var a := 0.30 + 0.18 * sin(Time.get_ticks_msec() * 0.006)
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, a), 2.0, true)

	# 发射脉冲
	if _pulse > 0.0:
		draw_arc(Vector2.ZERO, 18.0 + (1.0 - _pulse) * 18.0, 0.0, TAU, 24,
				Color(col.r, col.g, col.b, _pulse * 0.8), 2.0, true)

	_draw_hp_bar(60.0, -h - 8.0)
	super._draw()