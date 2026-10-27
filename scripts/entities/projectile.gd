class_name Projectile
extends Node2D
## 弹丸：追踪目标点飞行，命中即结算伤害；带 freeze 参数的冰晶弹命中后冻结目标
## 迫击炮弹（setup_splash）：飞向固定落点，到达后对溅射半径内的所有敌人结算群伤

const FX_SCENE := preload("res://scenes/fx/burst_fx.tscn")
const POOL_SCENE := preload("res://scenes/fx/lava_pool.tscn")

var target: Node2D = null
var damage := 10.0
var speed := 640.0
var tint := Color.WHITE
var freeze := 0.0
var splash_radius := 0.0       # >0 = 落点溅射模式（迫击炮 / 冰暴塔）
var target_pos := Vector2.ZERO
var slow_duration := 0.0       # >0 = 溅射命中后附加减速（冰暴塔）
var slow_factor := 1.0
var pool_radius := 0.0         # >0 = 落地生成岩浆池（熔岩塔）
var pool_time := 0.0

var _dir := Vector2.RIGHT


func _ready() -> void:
	z_index = 5


func setup(t: Node2D, dmg: float, spd: float, col: Color, freeze_dur := 0.0) -> void:
	target = t
	damage = dmg
	speed = spd
	tint = col
	freeze = freeze_dur


func setup_splash(pos: Vector2, dmg: float, spd: float, col: Color, radius: float,
		slow_dur := 0.0, slow_mul := 1.0) -> void:
	target = null
	target_pos = pos
	damage = dmg
	speed = spd
	tint = col
	splash_radius = radius
	slow_duration = slow_dur
	slow_factor = slow_mul


func setup_pool(pos: Vector2, spd: float, col: Color, radius: float, time: float) -> void:
	## 落点生成岩浆池（熔岩塔）：落地不造成直接伤害
	target = null
	target_pos = pos
	speed = spd
	tint = col
	pool_radius = radius
	pool_time = time


func _process(delta: float) -> void:
	if target != null:
		# 追踪模式：跟住目标，命中单体
		if not is_instance_valid(target) or target.dead:
			queue_free()
			return

		var to: Vector2 = target.global_position - global_position
		var dist := to.length()
		var step := speed * delta

		if dist <= step + 4.0:
			target.take_damage(damage)
			if freeze > 0.0 and target.has_method("apply_freeze"):
				target.apply_freeze(freeze)
			queue_free()
			return

		_dir = to / dist
		global_position += _dir * step
	else:
		# 落点模式：飞向固定点，到达后溅射群伤
		var to := target_pos - global_position
		var step := speed * delta
		if to.length() <= step + 2.0:
			_explode()
			return
		_dir = to / to.length()
		global_position += _dir * step


func _explode() -> void:
	if pool_radius > 0.0:
		var pool := POOL_SCENE.instantiate()
		pool.setup(global_position, pool_radius, pool_time)
		get_parent().add_child(pool)
	var r2 := splash_radius * splash_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= r2:
			e.take_damage(damage)
			if slow_duration > 0.0 and e.has_method("apply_slow"):
				e.apply_slow(slow_duration, slow_factor)
	var fx := FX_SCENE.instantiate() as BurstFx
	fx.position = global_position
	fx.tint = tint
	fx.max_radius = max(splash_radius * 0.7, pool_radius * 0.5, 14.0)
	get_parent().add_child(fx)
	queue_free()


func _draw() -> void:
	if freeze > 0.0:
		# 冰晶弹：沿飞行方向的菱形碎片 + 光晕
		var perp := Vector2(-_dir.y, _dir.x)
		draw_circle(Vector2.ZERO, 4.5, Color(tint.r, tint.g, tint.b, 0.25))
		draw_colored_polygon(PackedVector2Array([
			_dir * 6.5, perp * 2.6, -_dir * 6.5, -perp * 2.6,
		]), tint.lightened(0.35))
		draw_circle(Vector2.ZERO, 1.6, Color(1, 1, 1, 0.95))
	elif splash_radius > 0.0:
		# 迫击炮弹：大号圆弹 + 光晕
		draw_circle(Vector2.ZERO, 5.0, Color(tint.r, tint.g, tint.b, 0.25))
		draw_circle(Vector2.ZERO, 3.2, tint)
		draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.9))
	elif pool_radius > 0.0:
		# 岩浆弹：暗红大圆弹
		draw_circle(Vector2.ZERO, 5.5, Color(tint.r, tint.g, tint.b, 0.3))
		draw_circle(Vector2.ZERO, 3.4, tint)
		draw_circle(Vector2.ZERO, 1.6, Color(1, 0.7, 0.4, 0.95))
	else:
		draw_circle(Vector2.ZERO, 3.0, tint.lightened(0.35))
		draw_circle(Vector2.ZERO, 1.4, Color(1, 1, 1, 0.9))
