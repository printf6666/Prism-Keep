class_name GameConfig
extends RefCounted
## 全局配置：地图尺寸、配色、建筑/敌人数值、波次规则
## 所有可调数值集中在这里，改平衡性不用翻逻辑代码。

# ---------------- 地图 ----------------
const GRID_W := 80                     # 横向格数
const GRID_H := 80                     # 纵向格数
const CELL := 32.0                     # 单格边长（像素）
const BASE_CELL := Vector2i(39, 39)    # 大本营 2x2 的左上角格（地图正中央）
const BASE_SIZE := 2

# ---------------- 规则 ----------------
const START_GOLD := 220.0
const BASE_HP := 1000.0
const TOTAL_WAVES := 30
const FIRST_PREP := 8.0                # 首波准备时间（秒）
const PREP_TIME := 14.0                # 波与波之间的准备时间

# ---------------- 角色 ----------------
const PLAYER_SPEED := 190.0            # 角色移动速度（像素/秒）
const PLAYER_RADIUS := 9.0

# ---------------- 建筑类型 ----------------
enum Build { TOWER, MINE, WALL, FROST }

# ---------------- 升级 / 拆除 ----------------
const MAX_LEVEL := 3                # 防御塔最高等级
const UPGRADE_COST_RATE := 0.6      # 升级费用 = 造价 × 该系数 × 当前等级
const REFUND_BASE := 0.70           # 拆除返还：1 级的返还比例
const REFUND_STEP := 0.15           # 等级每高一级，返还比例递减
const REFUND_MIN := 0.10            # 返还比例下限

# ---------------- 配色（极简低饱和 + 高辨识度）----------------
const C_BG := Color(0.055, 0.067, 0.090)
const C_GRID_MINOR := Color(0.100, 0.125, 0.170)
const C_GRID_MAJOR := Color(0.160, 0.200, 0.270)
const C_MAP_EDGE := Color(0.220, 0.280, 0.380)
const C_BASE := Color(0.330, 0.800, 1.000)
const C_TOWER := Color(0.360, 0.860, 0.640)
const C_FROST := Color(0.620, 0.920, 1.000)
const C_MINE := Color(1.000, 0.780, 0.280)
const C_WALL := Color(0.600, 0.650, 0.740)
const C_TEXT := Color(0.880, 0.920, 0.980)
const C_TEXT_DIM := Color(0.550, 0.610, 0.720)
const C_OK := Color(0.360, 0.880, 0.600)
const C_BAD := Color(1.000, 0.400, 0.420)
const C_ENEMY_GRUNT := Color(1.000, 0.420, 0.420)
const C_ENEMY_RUNNER := Color(1.000, 0.820, 0.380)
const C_ENEMY_TANK := Color(0.460, 0.600, 1.000)
const C_ENEMY_BOSS := Color(0.760, 0.460, 1.000)


# ============================================================
#  坐标工具
# ============================================================
static func world_size() -> Vector2:
	return Vector2(float(GRID_W), float(GRID_H)) * CELL


static func base_center() -> Vector2:
	return Vector2(float(BASE_CELL.x) + float(BASE_SIZE) * 0.5,
			float(BASE_CELL.y) + float(BASE_SIZE) * 0.5) * CELL


static func is_base_cell(c: Vector2i) -> bool:
	return c.x >= BASE_CELL.x and c.x < BASE_CELL.x + BASE_SIZE \
		and c.y >= BASE_CELL.y and c.y < BASE_CELL.y + BASE_SIZE


# ============================================================
#  建筑定义
# ============================================================
static func build_def(kind: int) -> Dictionary:
	match kind:
		Build.TOWER:
			return {
				"name": "箭塔",
				"hotkey": "1",
				"cost": 50.0,
				"color": C_TOWER,
				"scene": "res://scenes/entities/arrow_tower.tscn",
				"desc": "自动索敌并射击，射程 5 格，可升级至 3 级",
			}
		Build.MINE:
			return {
				"name": "金矿",
				"hotkey": "2",
				"cost": 60.0,
				"color": C_MINE,
				"scene": "res://scenes/entities/gold_mine.tscn",
				"desc": "每 2 秒产出 10 金币",
			}
		Build.WALL:
			return {
				"name": "围墙",
				"hotkey": "3",
				"cost": 12.0,
				"color": C_WALL,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "阻挡敌人，逼其绕路或强拆",
			}
		Build.FROST:
			return {
				"name": "寒冰塔",
				"hotkey": "4",
				"cost": 70.0,
				"color": C_FROST,
				"scene": "res://scenes/entities/frost_tower.tscn",
				"desc": "冰晶弹命中后冰冻敌人，使其无法移动和攻击，可升级至 3 级",
			}
	return {}


# ============================================================
#  升级 / 拆除曲线
# ============================================================
static func upgrade_cost(kind: int, level: int) -> float:
	## 从 level 升到 level + 1 的费用（箭塔：30 / 60，寒冰塔：42 / 84）
	return build_def(kind)["cost"] * UPGRADE_COST_RATE * float(level)


static func refund_ratio(level: int) -> float:
	## 拆除返还比例：等级越高越低 —— 1 级 70%、2 级 55%、3 级 40%
	return maxf(REFUND_BASE - REFUND_STEP * float(level - 1), REFUND_MIN)


# ============================================================
#  敌人定义（按波次线性成长）
# ============================================================
static func enemy_def(type: String, wave: int) -> Dictionary:
	var base: Dictionary
	match type:
		"runner":
			base = {"hp": 26.0, "speed": 104.0, "dmg": 6.0, "bounty": 4.0,
				"radius": 8.0, "shape": "triangle", "color": C_ENEMY_RUNNER, "freeze_mul": 1.0}
		"tank":
			base = {"hp": 115.0, "speed": 40.0, "dmg": 18.0, "bounty": 9.0,
				"radius": 11.0, "shape": "square", "color": C_ENEMY_TANK, "freeze_mul": 1.0}
		"boss":
			base = {"hp": 460.0, "speed": 30.0, "dmg": 45.0, "bounty": 45.0,
				"radius": 15.0, "shape": "pentagon", "color": C_ENEMY_BOSS, "freeze_mul": 0.3}
		_:
			base = {"hp": 40.0, "speed": 62.0, "dmg": 8.0, "bounty": 4.0,
				"radius": 9.0, "shape": "circle", "color": C_ENEMY_GRUNT, "freeze_mul": 1.0}

	var w := float(maxi(wave, 1) - 1)
	var hp_mul := 1.0 + 0.16 * w
	var sp_mul := 1.0 + 0.012 * w
	var dm_mul := 1.0 + 0.08 * w

	return {
		"type": type,
		"hp": base["hp"] * hp_mul,
		"speed": base["speed"] * sp_mul,
		"dmg": base["dmg"] * dm_mul,
		"bounty": base["bounty"],
		"radius": base["radius"],
		"shape": base["shape"],
		"color": base["color"],
		"interval": 1.0,
		"freeze_mul": base["freeze_mul"],
	}


# ============================================================
#  波次编排
# ============================================================
static func wave_size(wave: int) -> int:
	return mini(8 + wave * 2, 64)


static func wave_plan(wave: int) -> Array:
	## 返回本波敌人类型列表，顺序即出生顺序
	var plan: Array = []
	var count := wave_size(wave)
	var boss_count := 0
	if wave % 10 == 0:
		boss_count = int(wave / 10)

	for i in count:
		var r := randf()
		var t := "grunt"
		if wave >= 3 and r < 0.30:
			t = "runner"
		elif wave >= 5 and r > 0.78:
			t = "tank"
		plan.append(t)

	for i in boss_count:
		plan.append("boss")

	return plan
