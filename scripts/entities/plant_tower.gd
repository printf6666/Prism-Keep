extends Building
## 植物炮塔：森之主召唤的临时炮塔，向射程内最近的敌人发射种子弹
## 存在一段时间后枯萎消失（不留残骸，直接消散）
## 火力与驻留时长来自森之主的局外升级线（MetaManager）

const PROJ_SCENE := preload("res://scenes/entities/projectile.tscn")

var lifetime := 45.0
var range_cells := GameConfig.PLANT_RANGE
var damage := 9.0
var fire_interval := GameConfig.PLANT_INTERVAL

var _cd := 0.0
var _scan_cd := 0.0
var _target: Node2D = null
var _aim := -PI * 0.5
var _sway := 0.0


func _ready() -> void:
	kind = GameConfig.Build.PLANT
	tint = GameConfig.HEROES["forest_lord"]["color"]
	max_hp = 120.0
	hp = max_hp
	max_level = 1   # 不可升级
	damage = MetaManager.hero_value("forest_lord", 0)      # 植物火力
	lifetime = MetaManager.hero_value("forest_lord", 1)    # 驻留时长
	_cd = randf() * 0.3
	_scan_cd = randf() * 0.1
	_sway = randf() * TAU


func _process(delta: float) -> void:
	super._process(delta)
	lifetime -= delta
	if lifetime <= 0.0:
		_destroy()
		return

	_cd -= delta
	_scan_cd -= delta
	_sway += delta * 2.0

	if _scan_cd <= 0.0:
		_scan_cd = 0.12
		_target = _acquire()

	if _target != null and is_instance_valid(_target):
		_aim = lerp_angle(_aim, global_position.angle_to_point(_target.global_position),
				clampf(delta * 10.0, 0.0, 1.0))
		if not silenced() and _cd <= 0.0 \
				and global_position.distance_squared_to(_target.global_position) \
						<= range_cells * range_cells * GameConfig.CELL * GameConfig.CELL:
			_cd = fire_interval
			_shoot(_target)

	queue_redraw()


func _acquire() -> Node2D:
	var reach := range_cells * GameConfig.CELL
	var best: Node2D = null
	var best_d := reach * reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _shoot(e: Node2D) -> void:
	var layer := get_tree().get_first_node_in_group("projectiles")
	if layer == null:
		return
	var p := PROJ_SCENE.instantiate() as Projectile
	p.global_position = global_position + Vector2(cos(_aim), sin(_aim)) * 10.0
	p.setup(e, damage * GameState.building_dmg_mul, 480.0, tint, 0.0, self)
	layer.add_child(p)


func _draw() -> void:
	var col := _body_color(tint)
	var half := GameConfig.CELL * 0.5 - 5.0

	# 花盆底座
	draw_circle(Vector2.ZERO, half * 0.8, Color(0.14, 0.12, 0.07), true)

	# 花瓣：随风向轻摆的 5 片叶瓣
	draw_set_transform(Vector2.ZERO, sin(_sway) * 0.15, Vector2.ONE)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var d := Vector2(cos(a), sin(a))
		draw_circle(d * 6.5, 4.0, col.darkened(0.2))
	draw_circle(Vector2.ZERO, 5.0, col)
	draw_circle(Vector2.ZERO, 2.2, col.lightened(0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 枯萎倒计时环（最后 10 秒显示）
	if lifetime < 10.0:
		var a := clampf(lifetime / 10.0, 0.0, 1.0)
		draw_arc(Vector2.ZERO, half, -PI * 0.5, -PI * 0.5 + TAU * a, 20,
				Color(1, 1, 1, 0.4), 1.5, true)

	_draw_hp_bar(20.0, -half - 6.0)
	super._draw()
