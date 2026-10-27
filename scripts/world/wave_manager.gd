extends Node
## 波次调度：准备计时 -> 按时间表从地图四边放怪 -> 全清后进入下一波
## 第 30 波清空即胜利

signal wave_started(w: int)
signal wave_cleared(w: int)
signal prep_tick(left: float)

enum St { PREP, SPAWN, DONE }

const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")

var state: int = St.PREP
var wave := 0
var prep_left := 0.0

var _queue: Array = []
var _elapsed := 0.0
var _active := false
var _enemies_root: Node2D


func _ready() -> void:
	_enemies_root = get_parent().get_node("Enemies")
	GameState.next_wave_pressed.connect(_on_skip)


func begin() -> void:
	_active = true
	wave = 0
	state = St.PREP
	prep_left = GameConfig.FIRST_PREP
	_queue.clear()
	prep_tick.emit(prep_left)


func _process(delta: float) -> void:
	if not _active or GameState.finished:
		return

	match state:
		St.PREP:
			prep_left -= delta
			prep_tick.emit(maxf(prep_left, 0.0))
			if prep_left <= 0.0:
				_start_wave()
		St.SPAWN:
			_elapsed += delta
			while not _queue.is_empty() and float(_queue[0]["t"]) <= _elapsed:
				var item: Dictionary = _queue.pop_front()
				_spawn(String(item["type"]), item["cell"])
			if _queue.is_empty() and get_tree().get_nodes_in_group("enemies").is_empty():
				_on_cleared()


func _on_skip() -> void:
	if state == St.PREP and not GameState.finished:
		# 提前开战的奖励：剩余准备秒数 × 10（与倒计时显示一致，向上取整）
		var reward := int(ceil(maxf(prep_left, 0.0))) * GameConfig.SKIP_BONUS_RATE
		if reward > 0:
			GameState.add_gold(float(reward))
			GameState.notice.emit("提前迎战，奖励 %d 金" % reward)
		_start_wave()


func _start_wave() -> void:
	wave += 1
	state = St.SPAWN
	_elapsed = 0.0
	GameState.set_wave(wave)
	wave_started.emit(wave)

	var plan := GameConfig.wave_plan(wave)
	var gate_count: int = clampi(1 + int(wave / 4), 1, 4)
	var gates := _pick_gates(gate_count)
	var gap: float = clampf(16.0 / float(maxi(plan.size(), 1)), 0.10, 0.75)

	_queue.clear()
	for i in plan.size():
		var gate: Vector2i = gates[i % gates.size()]
		_queue.append({
			"t": float(i) * gap,
			"type": plan[i],
			"cell": _jitter(gate, 5),
		})


func _on_cleared() -> void:
	wave_cleared.emit(wave)
	if wave >= GameConfig.TOTAL_WAVES:
		state = St.DONE
		GameState.finish(true)
	else:
		state = St.PREP
		prep_left = GameConfig.PREP_TIME


# ============================================================
#  出生点：地图四边随机
# ============================================================
func _pick_gates(n: int) -> Array:
	var sides := [0, 1, 2, 3]
	sides.shuffle()
	var gates: Array = []
	for i in n:
		var side: int = sides[i % 4]
		var c := Vector2i.ZERO
		match side:
			0:
				c = Vector2i(randi() % GameConfig.GRID_W, 0)
			1:
				c = Vector2i(randi() % GameConfig.GRID_W, GameConfig.GRID_H - 1)
			2:
				c = Vector2i(0, randi() % GameConfig.GRID_H)
			_:
				c = Vector2i(GameConfig.GRID_W - 1, randi() % GameConfig.GRID_H)
		gates.append(c)
	return gates


func _jitter(c: Vector2i, r: int) -> Vector2i:
	for attempt in 10:
		var p := c + Vector2i(randi_range(-r, r), randi_range(-r, r))
		p.x = clampi(p.x, 0, GameConfig.GRID_W - 1)
		p.y = clampi(p.y, 0, GameConfig.GRID_H - 1)
		var on_edge: bool = p.x == 0 or p.y == 0 \
				or p.x == GameConfig.GRID_W - 1 or p.y == GameConfig.GRID_H - 1
		if not on_edge:
			continue
		if Board.is_free(p):
			return p
	return c


func _spawn(type: String, cell: Vector2i) -> void:
	var def := GameConfig.enemy_def(type, wave)
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.setup(def)
	e.position = Board.cell_to_world(cell)
	_enemies_root.add_child(e)
