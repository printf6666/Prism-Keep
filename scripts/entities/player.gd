extends Node2D
## 玩家角色 / 英雄单位
## - WASD 自由移动，视角跟着角色走，移动方向即面朝方向
## - 碰撞：除路障外所有建筑都挡人；路障对角色是“可穿过”的（敌人仍会被它挡住）
## - 靠近大本营按 B：打开 / 关闭词条商店（用晶源购买全局词条）
## - 英雄系统（开始界面选择，存于 GameState.hero_id）：
##     炎拳   [Q] 全场点燃 + 易伤 ×2（15 秒），冷却 3 分钟
##     森之主 [Q] 部署 4 座植物炮塔（60 秒），冷却 5 分钟
##     圣女   被动：5×5 内的塔攻速 +10%、回血 2/秒、5% 免伤

var hero_id := ""
var hero_cd := 0.0
var _skill_pulse := 0.0
var _saint_scan := 0.0

var _face := -PI * 0.5
var _bob := 0.0
var _moving := false


func _ready() -> void:
	z_index = 7
	# 站在大本营正下方，避免和基地图形叠在一起看不见
	position = GameConfig.base_center() + Vector2(0.0, GameConfig.CELL * 2.5)
	hero_id = GameState.hero_id
	if not GameConfig.HEROES.has(hero_id):
		hero_id = ""


func _process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_moving = dir.length_squared() > 0.0001

	if _moving:
		_face = lerp_angle(_face, dir.angle(), clampf(delta * 16.0, 0.0, 1.0))
		var step := dir * GameConfig.PLAYER_SPEED * delta
		var p := position
		# 分轴移动：撞墙时可以贴着滑
		if _walkable(p + Vector2(step.x, 0.0)):
			p.x += step.x
		if _walkable(p + Vector2(0.0, step.y)):
			p.y += step.y
		position = p
		_bob += delta * 12.0
	else:
		_bob = lerp(_bob, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	# 英雄技能冷却
	if hero_cd > 0.0:
		hero_cd = maxf(0.0, hero_cd - delta)
	_skill_pulse = maxf(0.0, _skill_pulse - delta * 2.0)

	# 圣女光环：每帧刷新 5×5 内建筑的加速 / 回血 / 免伤盖章
	if hero_id == "saintess":
		_saint_aura(delta)

	# 词条商店开着时走远 → 自动关闭
	if GameState.affix_shop_open and not near_base():
		GameState.set_affix_shop(false)

	queue_redraw()


func near_base() -> bool:
	## 是否站在大本营占地范围外一圈以内（B 键打开词条商店的范围）
	var c := Board.cell_of(global_position)
	return c.x >= GameConfig.BASE_CELL.x - 1 and c.x <= GameConfig.BASE_CELL.x + GameConfig.BASE_SIZE \
			and c.y >= GameConfig.BASE_CELL.y - 1 and c.y <= GameConfig.BASE_CELL.y + GameConfig.BASE_SIZE


## 圣女被动光环：以玩家为中心 5×5 内的塔——冷却流逝 ×1.1、回血 2/秒、免伤盖章
func _saint_aura(delta: float) -> void:
	var pc := Board.cell_of(global_position)
	var stamp := Time.get_ticks_msec()
	for b in Board.buildings.values():
		if not is_instance_valid(b):
			continue
		var bc: Vector2i = b.cell
		if absi(bc.x - pc.x) <= 2 and absi(bc.y - pc.y) <= 2:
			b.saint_stamp = stamp
			b.cd_speed = GameConfig.SAINT_HASTE
			if b.hp > 0.0 and b.hp < b.max_hp:
				b.hp = minf(b.hp + GameConfig.SAINT_REGEN * delta, b.max_hp)
		elif b.cd_speed != 1.0:
			b.cd_speed = 1.0


func _cast_skill() -> void:
	var hero: Dictionary = GameConfig.HEROES.get(hero_id, {})
	if hero.is_empty() or not hero.get("active", false):
		if hero_id == "saintess":
			GameState.notice.emit("圣女：被动光环持续生效中")
		return
	if hero_cd > 0.0:
		GameState.notice.emit("%s 冷却中（%d 秒）" % [hero["name"], int(ceil(hero_cd))])
		return
	hero_cd = hero["skill_cd"]
	_skill_pulse = 1.0

	match hero_id:
		"flame_fist":
			# 炎拳之怒：全场点燃（1%/秒）并易伤（受伤 ×2），持续 15 秒
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.dead:
					continue
				e.apply_vuln(15.0)
				e.apply_burn(GameConfig.BURN_PCT + GameState.burn_bonus, 15.0, self)
			GameState.notice.emit("炎拳之怒：全场点燃，敌人易伤（受伤 ×2）15 秒")
		"forest_lord":
			# 森之主：在身边部署 4 座植物炮塔（对角优先，被占则用正交格补足）
			_deploy_plants()
			GameState.notice.emit("森之主：植物炮塔部署完毕（60 秒）")


## 森之主：部署 4 座植物炮塔（对角优先，占用的格子自动顺延）
func _deploy_plants() -> void:
	var scene := load("res://scenes/entities/plant_tower.tscn")
	var my_cell := Board.cell_of(global_position)
	var candidates: Array = [my_cell + Vector2i(1, 1), my_cell + Vector2i(-1, -1),
			my_cell + Vector2i(1, -1), my_cell + Vector2i(-1, 1),
			my_cell + Vector2i(1, 0), my_cell + Vector2i(-1, 0),
			my_cell + Vector2i(0, 1), my_cell + Vector2i(0, -1)]
	var placed := 0
	for c in candidates:
		if placed >= 4:
			break
		if not Board.is_free(c):
			continue
		var p = scene.instantiate()
		get_parent().add_child(p)
		p.place(c)
		placed += 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_Q:
			_cast_skill()
		elif k.keycode == KEY_B and near_base():
			GameState.set_affix_shop(not GameState.affix_shop_open)


func _walkable(p: Vector2) -> bool:
	var ws := GameConfig.world_size()
	var r := GameConfig.PLAYER_RADIUS
	if p.x < r or p.y < r or p.x > ws.x - r or p.y > ws.y - r:
		return false
	var b = Board.get_building(Board.cell_of(p))
	if b == null:
		return true
	# 路障：角色可以直接穿过去（敌人依旧被它挡住）
	return is_instance_valid(b) and b.barricade


## 角色面前一格：朝向主导轴方向的相邻格，G 键互动的目标
## （斜向移动时取 x / y 分量较大的一侧，保证结果永远是正交相邻格）
func front_cell() -> Vector2i:
	var dir := Vector2(cos(_face), sin(_face))
	var off := Vector2i.ZERO
	if absf(dir.x) >= absf(dir.y):
		off.x = 1 if dir.x >= 0.0 else -1
	else:
		off.y = 1 if dir.y >= 0.0 else -1
	return Board.cell_of(global_position) + off


func _draw() -> void:
	var r := GameConfig.PLAYER_RADIUS
	var accent := GameConfig.C_BASE
	var body := Color(0.92, 0.95, 1.00)
	if hero_id != "" and GameConfig.HEROES.has(hero_id):
		accent = GameConfig.HEROES[hero_id]["color"]
	var dir := Vector2(cos(_face), sin(_face))
	var perp := Vector2(-dir.y, dir.x)

	# 影子
	draw_circle(Vector2(0.0, 5.0), r * 0.95, Color(0, 0, 0, 0.30))

	# 双脚（走路时前后摆，露在身体下沿）
	var sw: float = sin(_bob) * 3.5 if _moving else 0.0
	draw_circle(Vector2(-4.5, 7.0 + sw), 3.2, body.darkened(0.45))
	draw_circle(Vector2(4.5, 7.0 - sw), 3.2, body.darkened(0.45))

	# 身体
	draw_circle(Vector2.ZERO, r, body)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, accent.darkened(0.25), 2.0, true)

	# 英雄光环（外环 = 英雄配色；技能释放时闪一圈）
	if hero_id != "":
		draw_arc(Vector2.ZERO, r + 4.5, 0.0, TAU, 24,
				Color(accent.r, accent.g, accent.b, 0.5 + _skill_pulse * 0.4), 2.0, true)
	if _skill_pulse > 0.0:
		draw_arc(Vector2.ZERO, r + 6.0 + (1.0 - _skill_pulse) * 14.0, 0.0, TAU, 24,
				Color(accent.r, accent.g, accent.b, _skill_pulse * 0.7), 2.5, true)

	# 朝向楔形（画在身体之上，指向当前移动方向）
	draw_colored_polygon(PackedVector2Array([
		dir * (r + 6.0),
		dir * (r * 0.30) + perp * 5.0,
		dir * (r * 0.30) - perp * 5.0,
	]), accent)

	# 头（顶视：一个小圆）
	draw_circle(Vector2.ZERO, r * 0.42, accent.lightened(0.35))
	draw_circle(Vector2.ZERO, r * 0.20, Color(1, 1, 1))
