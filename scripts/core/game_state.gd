extends Node
## 全局游戏状态 + UI 事件总线（自动加载单例：GameState）

signal gold_changed(value: float)
signal base_changed(hp: float, max_hp: float)
signal wave_changed(wave: int, total: int)
signal game_finished(win: bool)
signal notice(text: String)

# ---- 以下由 UI 发出，游戏层接收 ----
signal build_mode_changed(kind: int)
signal next_wave_pressed
signal speed_changed(mult: float)
signal building_selected(building)   # 点击已部署建筑时发出，null 表示取消选中

var gold := 0.0
var base_hp := 0.0
var base_hp_max := 0.0
var wave := 0
var total_waves := GameConfig.TOTAL_WAVES
var finished := false


func reset() -> void:
	gold = GameConfig.START_GOLD
	base_hp = GameConfig.BASE_HP
	base_hp_max = GameConfig.BASE_HP
	wave = 0
	total_waves = GameConfig.TOTAL_WAVES
	finished = false
	gold_changed.emit(gold)
	base_changed.emit(base_hp, base_hp_max)
	wave_changed.emit(wave, total_waves)


func add_gold(v: float) -> void:
	if finished:
		return
	gold += v
	gold_changed.emit(gold)


func can_afford(v: float) -> bool:
	return gold >= v


func try_spend(v: float) -> bool:
	if gold < v:
		return false
	gold -= v
	gold_changed.emit(gold)
	return true


func damage_base(v: float) -> void:
	if finished:
		return
	base_hp = maxf(0.0, base_hp - v)
	base_changed.emit(base_hp, base_hp_max)
	if base_hp <= 0.0:
		finish(false)


func set_wave(w: int) -> void:
	wave = w
	wave_changed.emit(wave, total_waves)


func finish(win: bool) -> void:
	if finished:
		return
	finished = true
	game_finished.emit(win)
