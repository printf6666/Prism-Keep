extends Node
## 棋盘数据 + 流场寻路（自动加载单例：Board）
##
## 两张流场：
##   dist_normal —— 所有建筑都挡路。敌人的默认路线，因此敌人天然“优先奔向大本营”，
##                  有路时绝不会去碰沿路的塔和墙。
##   dist_free   —— 什么都不挡。大本营被围死时的兜底：敌人直扑大本营，
##                  挡在路上的建筑（墙 / 塔）就当场拆掉。
##
## 敌人每帧只需要走向数值更小的邻格，不需要 A*，也不会有路径抖动。

signal layout_changed

const W := GameConfig.GRID_W
const H := GameConfig.GRID_H
const INF := 1.0e9

# 8 邻域：前 4 个正交，后 4 个对角
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

var buildings: Dictionary = {}   # idx -> Building 节点
var walls: Dictionary = {}       # idx -> true（buildings 的子集）
var ores: Dictionary = {}        # idx -> true（矿山格，金矿只能建在这里）
var dist_normal := PackedFloat32Array()
var dist_free := PackedFloat32Array()

var _dirty := false
var _cool := 0.0


func _ready() -> void:
	var total := W * H
	dist_normal.resize(total)
	dist_free.resize(total)
	rebuild()


func _process(delta: float) -> void:
	# 拆墙 / 拆塔可能成批发生，这里做节流，避免一帧内反复重算全图
	if _dirty:
		_cool -= delta
		if _cool <= 0.0:
			_dirty = false
			_cool = 0.25
			rebuild()


# ============================================================
#  坐标
# ============================================================
func idx(x: int, y: int) -> int:
	return y * W + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / GameConfig.CELL)),
			int(floor(world_pos.y / GameConfig.CELL)))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * GameConfig.CELL,
			(float(c.y) + 0.5) * GameConfig.CELL)


# ============================================================
#  占用查询
# ============================================================
func is_free(c: Vector2i) -> bool:
	if not in_bounds(c.x, c.y):
		return false
	if GameConfig.is_base_cell(c):
		return false
	return not buildings.has(idx(c.x, c.y))


func get_building(c: Vector2i):
	if not in_bounds(c.x, c.y):
		return null
	return buildings.get(idx(c.x, c.y), null)


func is_wall_cell(c: Vector2i) -> bool:
	if not in_bounds(c.x, c.y):
		return false
	return walls.has(idx(c.x, c.y))


## 是否为矿山格（金矿的唯一合法落点；只是地形标记，不阻挡通行）
func is_ore(c: Vector2i) -> bool:
	if not in_bounds(c.x, c.y):
		return false
	return ores.has(idx(c.x, c.y))


## 区域内所有格子是否可建（多格建筑放置用）
func is_free_area(top_left: Vector2i, size: Vector2i) -> bool:
	for dy in size.y:
		for dx in size.x:
			if not is_free(top_left + Vector2i(dx, dy)):
				return false
	return true


func ore_cells() -> Array:
	var out: Array = []
	for i in ores:
		out.append(Vector2i(i % W, int(i / float(W))))
	return out


## 场上是否存在某类建筑（改造车间等条件判定用）
func has_kind(k: int) -> bool:
	for b in buildings.values():
		if is_instance_valid(b) and int(b.kind) == k:
			return true
	return false


func register(b: Node, top_left: Vector2i, size: Vector2i = Vector2i.ONE) -> void:
	## 登记（支持多格建筑：每个格子都指向同一建筑节点）
	for dy in size.y:
		for dx in size.x:
			var c := top_left + Vector2i(dx, dy)
			var i := idx(c.x, c.y)
			buildings[i] = b
			if b.is_wall:
				walls[i] = true
	mark_dirty()


func unregister_building(b) -> void:
	## 注销建筑占用的全部格子
	for c in b.occupied_cells():
		var i := idx(c.x, c.y)
		buildings.erase(i)
		walls.erase(i)
	mark_dirty()


func mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_cool = 0.0


func reset() -> void:
	buildings.clear()
	walls.clear()
	generate_ores()
	_dirty = false
	rebuild()


## 每局随机生成矿山格：避开大本营，其余位置完全随机（数量见 GameConfig.ORE_COUNT）
func generate_ores() -> void:
	ores.clear()
	var guard := 0
	while ores.size() < GameConfig.ORE_COUNT and guard < 4000:
		guard += 1
		var c := Vector2i(randi_range(0, W - 1), randi_range(0, H - 1))
		if GameConfig.is_base_cell(c):
			continue
		ores[idx(c.x, c.y)] = true


# ============================================================
#  流场
# ============================================================
func rebuild() -> void:
	dist_normal = _bfs(true)
	dist_free = _bfs(false)
	layout_changed.emit()


func _bfs(block_all: bool) -> PackedFloat32Array:
	var total := W * H
	var d := PackedFloat32Array()
	d.resize(total)
	d.fill(INF)

	var q := PackedInt32Array()
	q.resize(total)
	var head := 0
	var tail := 0

	# 以 2x2 大本营为源点
	for oy in GameConfig.BASE_SIZE:
		for ox in GameConfig.BASE_SIZE:
			var si := (GameConfig.BASE_CELL.y + oy) * W + (GameConfig.BASE_CELL.x + ox)
			d[si] = 0.0
			q[tail] = si
			tail += 1

	while head < tail:
		var cur := q[head]
		head += 1
		var cx := cur % W
		var cy := int(cur / float(W))
		var cd := d[cur]

		for k in 8:
			var nx: int = cx + DX[k]
			var ny: int = cy + DY[k]
			if not in_bounds(nx, ny):
				continue
			var ni := ny * W + nx
			if d[ni] <= cd + 1.0:
				continue
			if block_all and buildings.has(ni):
				continue
			# 对角移动不允许“贴角穿墙”
			if block_all and k >= 4:
				if buildings.has(cy * W + nx):
					continue
				if buildings.has(ny * W + cx):
					continue
			d[ni] = cd + 1.0
			q[tail] = ni
			tail += 1

	return d


## 大本营到该格是否还有路（false = 被建筑彻底围死）
func has_route(cell: Vector2i) -> bool:
	if not in_bounds(cell.x, cell.y):
		return false
	return dist_normal[cell.y * W + cell.x] < INF


## 沿“绕开建筑”的路线走一步；返回 (-1,-1) 表示已到大本营或无路可走
func next_cell(cell: Vector2i) -> Vector2i:
	return _step(cell, false)


## 沿“无视建筑”的路线走一步（被围死时用来直扑大本营）
func next_cell_free(cell: Vector2i) -> Vector2i:
	return _step(cell, true)


func _step(cell: Vector2i, use_free: bool) -> Vector2i:
	if not in_bounds(cell.x, cell.y):
		return Vector2i(-1, -1)

	var i := cell.y * W + cell.x
	var best: float = dist_free[i] if use_free else dist_normal[i]
	var bx := -1
	var by := -1

	for k in 8:
		var nx: int = cell.x + DX[k]
		var ny: int = cell.y + DY[k]
		if not in_bounds(nx, ny):
			continue
		var ni := ny * W + nx
		var nd: float = dist_free[ni] if use_free else dist_normal[ni]
		if nd >= best:
			continue
		if not use_free and k >= 4:
			if dist_normal[cell.y * W + nx] >= INF or dist_normal[ny * W + cell.x] >= INF:
				continue
		best = nd
		bx = nx
		by = ny

	return Vector2i(bx, by)


## 敌人是否已经踩在大本营上
func at_base(cell: Vector2i) -> bool:
	return GameConfig.is_base_cell(cell)
