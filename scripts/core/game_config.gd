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
const ORE_COUNT := 20                  # 矿山格数量（金矿只能建在矿山格上）

# ---------------- 规则 ----------------
const START_GOLD := 220.0
const BASE_HP := 1000.0
const TOTAL_WAVES := 100
const FIRST_PREP := 8.0                # 首波准备时间（秒）
const PREP_TIME := 14.0                # 波与波之间的准备时间
const SKIP_BONUS_RATE := 10            # 提前下一波奖励 = 剩余秒数 × 该系数

# ---------------- 角色 ----------------
const PLAYER_SPEED := 230.0            # 角色移动速度（像素/秒）
const PLAYER_RADIUS := 9.0

# ---------------- 建筑类型 ----------------
enum Build { TOWER, MINE, WALL, FROST, TOWER_RAPID, TOWER_RANGE, BARRICADE, CANNON, CANNON_HEAVY, CANNON_MORTAR, FROST_STORM, FROST_BEAM, RETOOL, FLAME, FLAME_BLAZE, MAGMA }

# ---------------- 升级 / 拆除 ----------------
const MAX_LEVEL := 3                # 防御塔最高等级
const UPGRADE_COST_RATE := 1.1      # 升级费用 = 1.1 ×（建造价格 + 前一次升级价格）
const REFUND_BASE := 0.70           # 拆除返还：1 级的返还比例
const REFUND_STEP := 0.15           # 等级每高一级，返还比例递减
const REFUND_MIN := 0.10            # 返还比例下限

# ---------------- 满级箭塔分支 ----------------
const BRANCH_COST := 120.0          # 分支定型费用（两种分支相同）
const RAPID_INTERVAL := 0.16        # 快速射击箭塔射击间隔（秒）
const RANGE_BRANCH_RANGE := 8.0     # 大范围射击箭塔射程（格）
const RANGE_BRANCH_DMG_MUL := 1.15  # 大范围射击箭塔伤害倍率

# ---------------- 满级炮塔分支 ----------------
const CANNON_BRANCH_COST := 150.0   # 分支定型费用（两种分支相同）
const HEAVY_DAMAGE := 120.0         # 重型炮单发伤害（单体）
const HEAVY_INTERVAL := 1.5         # 重型炮射击间隔（秒）
const MORTAR_DAMAGE := 45.0         # 迫击炮单发溅射伤害（群体）
const MORTAR_INTERVAL := 1.5        # 迫击炮射击间隔（秒）
const MORTAR_RANGE := 8.5           # 迫击炮射程（格）
const MORTAR_SPLASH := 64.0         # 迫击炮溅射半径（像素，覆盖 4×4 格）

# ---------------- 满级寒冰塔分支 ----------------
const FROST_BRANCH_COST := 140.0    # 分支定型费用（两种分支相同）
const STORM_DAMAGE := 35.0          # 冰暴塔单发爆炸伤害（群体）
const STORM_INTERVAL := 1.4         # 冰暴塔射击间隔（秒）
const STORM_RANGE := 4.5            # 冰暴塔射程（格）
const STORM_SPLASH := 48.0          # 冰暴塔爆炸半径（像素，覆盖 3×3 格）
const STORM_SLOW_TIME := 2.5        # 冰暴塔减速持续时间（秒）
const STORM_SLOW_FACTOR := 0.5      # 冰暴塔减速幅度（0.5 = 移速减半）
const BEAM_DPS := 20.0              # 不朽塔激光基础伤害（每秒）
const BEAM_RAMP := 0.4              # 激光每锁定 1 秒伤害提升的比例
const BEAM_RAMP_CAP_BOSS := 3.0     # 激光增伤上限：Boss（倍）
const BEAM_RAMP_CAP_ELITE := 5.0    # 激光增伤上限：精英怪 = 重甲（倍）；其余敌人无上限
const BEAM_RANGE := 5.0             # 不朽塔射程（格）

# ---------------- 技能点 / 改造车间加成 ----------------
const SP_MOB := 1                     # 击杀小怪（普通 / 疾行）技能点
const SP_ELITE := 50                  # 击杀精英怪（重甲）技能点
const SP_BOSS := 300                  # 击杀 Boss 技能点
const RETOOL_BUFFS := [
	{"id": "tower", "name": "防御塔攻击力 +10%", "base_cost": 100, "max_lv": 5},
	{"id": "wall", "name": "围墙 / 路障血量 +20%", "base_cost": 60, "max_lv": 5},
	{"id": "mine", "name": "金矿产量 +0.5", "base_cost": 50, "max_lv": 10},
	{"id": "burn", "name": "灼烧效果 +0.5%", "base_cost": 1500, "max_lv": 5, "flat": true},
]


static func buff_cost(i: int, lv: int) -> int:
	## 第 i 项加成从 lv 升到 lv + 1 的技能点费用（逐级递增；flat = 固定价）
	var def: Dictionary = RETOOL_BUFFS[i]
	if def.get("flat", false):
		return int(def["base_cost"])
	return int(def["base_cost"]) * (lv + 1)


# ---------------- 灼烧 / 喷火器 ----------------
const BURN_PCT := 0.01                # 基础灼烧：每秒燃烧最大生命值的比例
const BURN_TIME := 10.0               # 灼烧持续时间（秒）
const FLAME_CONE_DEG := 45.0          # 喷火器扇形角度
const FLAME_BRANCH_COST := 130.0      # 满级喷火器分支定型费用
const BLAZE_RANGE := 7.0              # 烈炎塔射程（格）
const MAGMA_RANGE := 4.5              # 熔岩塔投掷射程（格）
const MAGMA_INTERVAL := 2.5           # 熔岩塔投掷间隔（秒）
const MAGMA_POOL_RADIUS := 96.0       # 岩浆池半径（像素，覆盖约 3 格）
const MAGMA_POOL_TIME := 5.0          # 岩浆池持续时间（秒）
const LAVA_BURN_TIME := 3.0           # 离开岩浆后灼烧残留（秒）
const LAVA_BURN_MUL := 2.0            # 岩浆中的灼烧倍率（含技能点加成翻倍）


# ---------------- 配色（极简低饱和 + 高辨识度）----------------
const C_BG := Color(0.055, 0.067, 0.090)
const C_GRID_MINOR := Color(0.100, 0.125, 0.170)
const C_GRID_MAJOR := Color(0.160, 0.200, 0.270)
const C_MAP_EDGE := Color(0.220, 0.280, 0.380)
const C_BASE := Color(0.330, 0.800, 1.000)
const C_TOWER := Color(0.360, 0.860, 0.640)
const C_TOWER_RAPID := Color(0.720, 0.960, 0.420)   # 快速射击箭塔（黄绿）
const C_TOWER_RANGE := Color(0.220, 0.660, 0.560)   # 大范围射击箭塔（青绿）
const C_FROST := Color(0.620, 0.920, 1.000)
const C_FROST_STORM := Color(0.420, 0.800, 0.950)    # 冰暴塔（深冰蓝）
const C_FROST_BEAM := Color(0.820, 0.780, 1.000)     # 不朽塔（淡雪紫）
const C_RETOOL := Color(0.800, 0.680, 1.000)         # 改造车间（薰衣草紫）
const C_FLAME := Color(0.980, 0.500, 0.180)          # 喷火器（烈焰橙）
const C_FLAME_BLAZE := Color(1.000, 0.320, 0.120)    # 烈炎塔（炽焰红橙）
const C_MAGMA := Color(0.720, 0.160, 0.200)          # 熔岩塔（熔岩暗红）
const C_CANNON := Color(0.930, 0.520, 0.380)          # 炮塔（暖橙红）
const C_CANNON_HEAVY := Color(0.950, 0.340, 0.300)    # 重型炮（深红）
const C_CANNON_MORTAR := Color(0.760, 0.720, 0.400)   # 迫击炮（橄榄绿）
const C_MINE := Color(1.000, 0.780, 0.280)
const C_WALL := Color(0.600, 0.650, 0.740)
const C_BARRICADE := Color(0.950, 0.620, 0.300)   # 路障（警示橙）
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
				"desc": "自动索敌并射击，射程 5 格，可升级至 3 级后分支定型",
			}
		Build.MINE:
			return {
				"name": "金矿",
				"hotkey": "2",
				"cost": 60.0,
				"color": C_MINE,
				"scene": "res://scenes/entities/gold_mine.tscn",
				"desc": "只能建在矿山格上，每 2 秒产出 3 金币",
			}
		Build.WALL:
			return {
				"name": "围墙",
				"hotkey": "3",
				"cost": 12.0,
				"color": C_WALL,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "阻挡敌人，普通敌人不会攻击它（重甲 / Boss 可强拆）",
			}
		Build.BARRICADE:
			return {
				"name": "路障",
				"hotkey": "5",
				"cost": 20.0,
				"color": C_BARRICADE,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "嘲讽：路过的敌人都会攻击它，血量比围墙高，替塔吸收火力",
			}
		Build.FROST:
			return {
				"name": "寒冰塔",
				"hotkey": "4",
				"cost": 70.0,
				"color": C_FROST,
				"scene": "res://scenes/entities/frost_tower.tscn",
				"desc": "冰晶弹命中后冰冻敌人，使其无法移动和攻击，可升级至 3 级后分支定型",
			}
		Build.FROST_STORM:
			return {
				"name": "冰暴塔",
				"hotkey": "",
				"cost": FROST_BRANCH_COST,
				"color": C_FROST_STORM,
				"scene": "res://scenes/entities/frost_tower.tscn",
				"desc": "满级寒冰塔分支：冰暴弹爆炸覆盖 3×3 格，伤害并减速所有命中敌人",
			}
		Build.FROST_BEAM:
			return {
				"name": "不朽塔",
				"hotkey": "",
				"cost": FROST_BRANCH_COST,
				"color": C_FROST_BEAM,
				"scene": "res://scenes/entities/frost_tower.tscn",
				"desc": "满级寒冰塔分支：激光锁定并冻结单个敌人，伤害随锁定时间提升，目标死亡后重置",
			}
		Build.TOWER_RAPID:
			return {
				"name": "快速射击箭塔",
				"hotkey": "",
				"cost": BRANCH_COST,
				"color": C_TOWER_RAPID,
				"scene": "res://scenes/entities/arrow_tower.tscn",
				"desc": "满级箭塔分支：攻速极快（间隔 0.16s），射程不变",
			}
		Build.TOWER_RANGE:
			return {
				"name": "大范围射击箭塔",
				"hotkey": "",
				"cost": BRANCH_COST,
				"color": C_TOWER_RANGE,
				"scene": "res://scenes/entities/arrow_tower.tscn",
				"desc": "满级箭塔分支：射程扩至 8 格，伤害 ×1.15",
			}
		Build.CANNON:
			return {
				"name": "炮塔",
				"hotkey": "6",
				"cost": 90.0,
				"color": C_CANNON,
				"scene": "res://scenes/entities/cannon_tower.tscn",
				"desc": "重炮系防御塔，可升级至 3 级后分支定型",
			}
		Build.CANNON_HEAVY:
			return {
				"name": "重型炮",
				"hotkey": "",
				"cost": CANNON_BRANCH_COST,
				"color": C_CANNON_HEAVY,
				"scene": "res://scenes/entities/cannon_tower.tscn",
				"desc": "满级炮塔分支：单发 120 大量伤害，优先轰击血量上限最高的敌人",
			}
		Build.CANNON_MORTAR:
			return {
				"name": "迫击炮",
				"hotkey": "",
				"cost": CANNON_BRANCH_COST,
				"color": C_CANNON_MORTAR,
				"scene": "res://scenes/entities/cannon_tower.tscn",
				"desc": "满级炮塔分支：射程 8.5 格的群伤曲射，优先轰击敌人最密集处",
			}
		Build.RETOOL:
			return {
				"name": "改造车间",
				"hotkey": "7",
				"cost": 500.0,
				"color": C_RETOOL,
				"scene": "res://scenes/entities/retool_shop.tscn",
				"footprint": Vector2i(5, 5),
				"desc": "5×5 功能建筑，易被敌人攻击：靠近按 I 用技能点购买全局加成；也可改造已定型塔的分支",
			}
		Build.FLAME:
			return {
				"name": "喷火器",
				"hotkey": "8",
				"cost": 80.0,
				"color": C_FLAME,
				"scene": "res://scenes/entities/flame_tower.tscn",
				"desc": "45° 扇形火舌，点燃敌人：每秒烧 1% 最大生命值，持续 10 秒，可升级至 3 级后分支",
			}
		Build.FLAME_BLAZE:
			return {
				"name": "烈炎塔",
				"hotkey": "",
				"cost": FLAME_BRANCH_COST,
				"color": C_FLAME_BLAZE,
				"scene": "res://scenes/entities/flame_tower.tscn",
				"desc": "满级喷火器分支：射程扩至 7 格的烈焰扇形",
			}
		Build.MAGMA:
			return {
				"name": "熔岩塔",
				"hotkey": "",
				"cost": FLAME_BRANCH_COST,
				"color": C_MAGMA,
				"scene": "res://scenes/entities/flame_tower.tscn",
				"desc": "满级喷火器分支：向敌人密集处投掷岩浆，灼烧 2%/秒并蔓延约 3 格，走出仍残留灼烧",
			}
	return {}


# ============================================================
#  建筑分类
# ============================================================
static func is_tower_kind(kind: int) -> bool:
	## 炮塔类（敌人被围死时优先拆，选中框 / 面前格显示射程圈）
	return kind == Build.TOWER or kind == Build.FROST \
			or kind == Build.TOWER_RAPID or kind == Build.TOWER_RANGE \
			or kind == Build.CANNON or kind == Build.CANNON_HEAVY or kind == Build.CANNON_MORTAR \
			or kind == Build.FROST_STORM or kind == Build.FROST_BEAM \
			or kind == Build.FLAME or kind == Build.FLAME_BLAZE or kind == Build.MAGMA


# ============================================================
#  升级 / 拆除曲线
# ============================================================
static func upgrade_cost(kind: int, level: int) -> float:
	## 从 level 升到 level + 1 的费用 = 1.1 ×（建造价格 + 前一次升级价格）
	## 首次升级没有"前一次"，即 1.1 × 造价（箭塔 55 / 116，寒冰塔 77 / 162，炮塔 99 / 208）
	var prev := 0.0
	if level > 1:
		prev = upgrade_cost(kind, level - 1)
	return roundf(UPGRADE_COST_RATE * (build_def(kind)["cost"] + prev))


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
				"radius": 8.0, "shape": "triangle", "color": C_ENEMY_RUNNER, "freeze_mul": 1.0, "breaker": false}
		"tank":
			base = {"hp": 115.0, "speed": 40.0, "dmg": 18.0, "bounty": 9.0,
				"radius": 11.0, "shape": "square", "color": C_ENEMY_TANK, "freeze_mul": 1.0, "breaker": true}
		"boss":
			base = {"hp": 460.0, "speed": 30.0, "dmg": 45.0, "bounty": 45.0,
				"radius": 15.0, "shape": "pentagon", "color": C_ENEMY_BOSS, "freeze_mul": 0.3, "breaker": true}
		_:
			base = {"hp": 40.0, "speed": 62.0, "dmg": 8.0, "bounty": 4.0,
				"radius": 9.0, "shape": "circle", "color": C_ENEMY_GRUNT, "freeze_mul": 1.0, "breaker": false}

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
		"breaker": base["breaker"],
	}


# ============================================================
#  波次编排
# ============================================================
static func wave_size(wave: int) -> int:
	return mini(10 + wave * 3, 90)


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
