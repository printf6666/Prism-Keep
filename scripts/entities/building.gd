class_name Building
extends Node2D
## 所有建筑的基类：占格、血量、受击闪白、升级与拆除、被摧毁时的爆炸特效

const FX_SCENE := preload("res://scenes/fx/burst_fx.tscn")

var cell := Vector2i.ZERO      # 占格左上角
var footprint := Vector2i.ONE  # 占地格数（改造车间 5×5）
var kind := 0
var is_wall := false
var barricade := false  # 路障标记（围墙变体，add_child 前设置，_ready 按它初始化）
var max_hp := 100.0
var hp := 100.0
var tint := Color.WHITE
var level := 1          # 当前等级（防御塔可升级，其余固定 1 级）
var max_level := 1
var invested := 0.0     # 累计投入（建造 + 升级），拆除时按比例返还

var _flash := 0.0
var _up_pulse := 0.0


func place(c: Vector2i) -> void:
	cell = c   # 左上角格
	position = Board.cell_to_world(c) + Vector2(footprint - Vector2i.ONE) * (GameConfig.CELL * 0.5)
	invested = GameConfig.build_def(kind)["cost"]
	Board.register(self, c, footprint)


func occupied_cells() -> Array:
	var out: Array = []
	for dy in footprint.y:
		for dx in footprint.x:
			out.append(cell + Vector2i(dx, dy))
	return out


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		_destroy()


# ============================================================
#  升级 / 拆除
# ============================================================
func can_upgrade() -> bool:
	return level < max_level


func upgrade_cost() -> float:
	return GameConfig.upgrade_cost(kind, level)


func refund_value() -> float:
	## 现在拆除能拿回多少金币
	return GameConfig.refund_ratio(level) * invested


func can_branch() -> bool:
	## 满级后能否分支定型（默认不可；箭塔 / 炮塔子类覆写）
	return false


func branch_options() -> Array:
	## 分支可选的类型列表（默认无）
	return []


func branch_cost() -> float:
	return 0.0


func branch_to(_new_kind: int) -> bool:
	## 分支定型：改 kind / 外观 / 数值，之后不可再升级；默认不可用
	return false


func can_retrofit() -> bool:
	## 已定型分支且场上存在改造车间时可改为另一分支（子类覆写）
	return false


func retrofit_options() -> Array:
	## 可改造成的分支类型列表（默认无）
	return []


func retrofit_cost() -> float:
	## 改造费用默认与分支定型相同
	return branch_cost()


func retrofit_to(_new_kind: int) -> bool:
	## 付费改为另一分支（保留等级，数值按新分支重置）；默认不可用
	return false


func upgrade() -> bool:
	## 扣钱升一级，返回是否成功；属性成长由子类 _on_upgraded 决定
	if not can_upgrade():
		return false
	var cost := upgrade_cost()
	if not GameState.try_spend(cost):
		return false
	invested += cost
	level += 1
	_on_upgraded()
	_up_pulse = 1.0
	queue_redraw()
	return true


func demolish() -> void:
	## 玩家主动拆除：按当前等级的返还比例拿回部分投入
	if hp <= 0.0:
		return
	GameState.add_gold(roundf(refund_value()))
	_destroy()


func _on_upgraded() -> void:
	## 默认升级收益：血量上限 +30%，并回复等量血量；子类 super 后追加自身成长
	var gain := ceilf(max_hp * 0.3)
	max_hp += gain
	hp += gain


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.5)
		queue_redraw()
	if _up_pulse > 0.0:
		_up_pulse = maxf(0.0, _up_pulse - delta * 2.0)
		queue_redraw()


func _destroy() -> void:
	Board.unregister_building(self)
	_spawn_fx()
	queue_free()


func _spawn_fx() -> void:
	var fx := FX_SCENE.instantiate() as BurstFx
	fx.position = position
	fx.tint = tint
	fx.max_radius = 26.0
	get_parent().add_child(fx)


## 子类绘制时统一取“受击提亮”的颜色
func _body_color(base: Color) -> Color:
	if _flash > 0.0:
		return base.lerp(Color(1, 1, 1), _flash * 0.75)
	return base


## 等级星标 + 升级脉冲；塔类在 _draw 末尾调用 super._draw() 带出
func _draw() -> void:
	if _up_pulse > 0.0:
		draw_arc(Vector2.ZERO, GameConfig.CELL * (0.45 + (1.0 - _up_pulse) * 0.55),
				0.0, TAU, 24, Color(tint.r, tint.g, tint.b, _up_pulse * 0.65), 2.0, true)
	if level >= 2:
		var pip_y := GameConfig.CELL * 0.5 - 7.0
		var col := tint.lightened(0.35)
		for i in level:
			var x := (float(i) - float(level - 1) * 0.5) * 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, pip_y - 3.0), Vector2(x + 2.2, pip_y),
				Vector2(x, pip_y + 3.0), Vector2(x - 2.2, pip_y),
			]), col)


## 血条：仅在掉血后显示
func _draw_hp_bar(width: float, y: float) -> void:
	if hp >= max_hp:
		return
	var p := clampf(hp / max_hp, 0.0, 1.0)
	var h := 3.0
	draw_rect(Rect2(-width * 0.5, y, width, h), Color(0, 0, 0, 0.55), true)
	var c: Color = GameConfig.C_OK
	if p <= 0.25:
		c = GameConfig.C_BAD
	elif p <= 0.5:
		c = Color(1.0, 0.78, 0.28)
	draw_rect(Rect2(-width * 0.5, y, width * p, h), c, true)
