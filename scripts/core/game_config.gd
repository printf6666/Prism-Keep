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
const RICH_ORE_COUNT := 3              # 大金矿数量（距基地 15 格以外，产金翻倍）
const RICH_ORE_MIN_DIST := 15          # 大金矿距基地的最小切比雪夫距离
const RICH_INCOME_MUL := 2.0           # 大金矿上的金矿产出倍率

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
enum Build { TOWER, MINE, WALL, FROST, TOWER_RAPID, TOWER_RANGE, BARRICADE, CANNON, CANNON_HEAVY, CANNON_MORTAR, FROST_STORM, FROST_BEAM, RETOOL, FLAME, FLAME_BLAZE, MAGMA, WALL_DOMAIN, WALL_MEMORY, BARRICADE_TURTLE, BARRICADE_THORNS, DEATH, DEATH_SILO, DEATH_FERRY }

# ---------------- 升级 / 拆除 ----------------
const MAX_LEVEL := 3                # 塔最高等级
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
	{"id": "tower", "name": "塔攻击力 +10%", "base_cost": 100, "max_lv": 5,
		"desc": "所有塔的攻击力提升 10%"},
	{"id": "wall", "name": "围墙 / 路障血量 +20%", "base_cost": 60, "max_lv": 5,
		"desc": "围墙与路障的血量提升 20%，已建成的立即回补"},
	{"id": "mine", "name": "金矿产量 +0.5", "base_cost": 50, "max_lv": 10,
		"desc": "金矿每次产出额外 +0.5 金"},
	{"id": "burn", "name": "灼烧效果 +0.5%", "base_cost": 1500, "max_lv": 5, "flat": true,
		"desc": "灼烧每秒伤害提升 0.5% 最大生命值（岩浆中翻倍）"},
	{"id": "dire", "name": "水深火热", "base_cost": 3000, "max_lv": 1,
		"desc": "解锁：被冰暴减速且身处岩浆的敌人，负面效果翻倍并陷入虚弱（受到的伤害 ×3）"},
	{"id": "apocalypse", "name": "灭世", "base_cost": APOCALYPSE_COST, "max_lv": 1, "action": true,
		"desc": "消耗 10000 技能点：死神塔连射 10 颗巨型核弹，每颗 15×15 范围、20 秒核辐射，对 Boss 造成 50% 伤害；使用次数无上限"},
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

# ---------------- 墙体 / 路障分支 ----------------
const WALL_BRANCH_COST := 40.0        # 城墙分支定型费用
const BARRICADE_BRANCH_COST := 60.0   # 路障分支定型费用
const DOMAIN_REDUCTION := 0.05        # 绝对领域：范围内建筑的免伤比例
const DOMAIN_SIZE := 5                # 绝对领域覆盖格数（5×5）
const MEMORY_REGEN := 2.0             # 记忆之石：每秒恢复生命
const TURTLE_REDUCTION := 0.05        # 龟壳：每个攻击者提供的免伤
const TURTLE_CAP := 0.5               # 龟壳免伤上限
const THORNS_PCT := 0.005             # 荆棘：反弹附近敌人最大生命值的比例
const THORNS_RADIUS := 64.0           # 荆棘反伤半径（像素，约 2 格）

# ---------------- 死神（超级武器） ----------------
const DEATH_INTERVAL := 45.0          # 攻击间隔（秒，非常低）
const DEATH_RADIUS := 160.0           # 打击半径（像素，覆盖 10×10 格）
const DEATH_BOSS_DMG_PCT := 0.05      # 1 级死神对 Boss 的伤害（最大生命值比例）
const DEATH_BOSS_DMG_STEP := 0.05     # 每升一级对 Boss 伤害 +5%
const DEATH_MAX_LEVEL := 3            # 死神最高 3 级，满级后分支进化
const DEATH_BRANCH_COST := 3000.0     # 死神分支进化费用
const DEATH_RADIATION_PCT := 0.10     # 核辐射：每秒扣除敌人最大生命值的比例
const DEATH_RADIATION_TIME := 15.0    # 核辐射持续时间（秒）
const DEATH_SHELL_SPEED := 450.0      # 炮弹飞行速度

# ---------------- 灭世（改造车间技能） ----------------
const APOCALYPSE_COST := 10000        # 每次使用的技能点消耗（使用次数无上限）
const APOCALYPSE_NUKES := 10          # 巨型核弹数量
const APOCALYPSE_RADIUS := 240.0      # 单颗打击半径（像素，覆盖 15×15 格）
const APOCALYPSE_RAD_TIME := 20.0     # 核辐射持续时间（秒）
const APOCALYPSE_BOSS_PCT := 0.5      # 灭世对 Boss 的伤害（最大生命值比例）

# ---------------- 死神分支：核弹井 / 灵魂摆渡者 ----------------
const SILO_COOLDOWN := 180.0          # 核弹井冷却（3 分钟）
const SILO_AREA_MUL := 6.0            # 打击面积为初始死神的 6 倍（半径 ×√6）
const SILO_BOSS_MUL := 6.0            # 对 Boss 伤害为初始死神的 6 倍
const FERRY_SOUL_ELITE := 2           # 灵魂：精英怪
const FERRY_SOUL_BOSS := 5            # 灵魂：Boss
const FERRY_SOUL_MOB := 1             # 灵魂：小怪
const FERRY_THRESHOLD := 100          # 灵魂阈值（达到后可右键释放）
const FERRY_BASE_PCT := 0.2           # 灵魂冲击：基础伤害（最大生命值比例）
const FERRY_STEP_PCT := 0.01          # 每多 100 灵魂 +1%
const FERRY_BOSS_CAP := 0.2           # 对 Boss 的伤害上限


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
const C_WALL_DOMAIN := Color(0.400, 0.700, 1.000)    # 绝对领域（护盾蓝）
const C_WALL_MEMORY := Color(0.500, 0.920, 0.550)    # 记忆之石（翠绿）
const C_WALL_TURTLE := Color(0.420, 0.720, 0.580)    # 龟壳（青甲）
const C_WALL_THORNS := Color(0.600, 0.850, 0.300)    # 荆棘（毒绿）
const C_DEATH := Color(0.520, 0.440, 0.620)          # 死神（死亡紫灰）
const C_DEATH_SILO := Color(0.640, 0.520, 0.320)     # 核弹井（沙褐钢铁）
const C_DEATH_FERRY := Color(0.420, 0.820, 0.780)    # 灵魂摆渡者（幽魂青）
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
	## 包装层：统一注入 "weapon"（会攻击的塔）与 "range"（射程圈）标记，
	## 后续新增建筑在此登记即可自动进入塔的各类体系
	var def := _build_def(kind)
	if def.is_empty():
		return def
	def["weapon"] = not NON_WEAPON.has(kind)
	def["range"] = def.get("range", -1.0)
	return def


## 不会攻击的建筑（其余定义默认视为会攻击的塔）
const NON_WEAPON := [Build.MINE, Build.WALL, Build.BARRICADE, Build.RETOOL,
		Build.WALL_DOMAIN, Build.WALL_MEMORY, Build.BARRICADE_TURTLE, Build.BARRICADE_THORNS]


static func _build_def(kind: int) -> Dictionary:
	match kind:
		Build.TOWER:
			return {
				"name": "箭塔",
				"hotkey": "1",
				"cost": 50.0,
				"color": C_TOWER,
				"scene": "res://scenes/entities/arrow_tower.tscn",
				"range": 5.0,
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
				"range": 4.0,
				"desc": "冰晶弹命中后冰冻敌人，使其无法移动和攻击，可升级至 3 级",
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
				"range": 4.5,
				"desc": "重炮系塔，可升级至 3 级后分支定型",
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
				"range": 3.0,
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
		Build.WALL_DOMAIN:
			return {
				"name": "绝对领域",
				"hotkey": "",
				"cost": WALL_BRANCH_COST,
				"color": C_WALL_DOMAIN,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "满级城墙分支：主动承受 5×5 内建筑所受的攻击，并赋予范围内建筑 5% 免伤",
			}
		Build.WALL_MEMORY:
			return {
				"name": "记忆之石",
				"hotkey": "",
				"cost": WALL_BRANCH_COST,
				"color": C_WALL_MEMORY,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "满级城墙分支：每秒恢复 2 点生命值",
			}
		Build.BARRICADE_TURTLE:
			return {
				"name": "龟壳",
				"hotkey": "",
				"cost": BARRICADE_BRANCH_COST,
				"color": C_WALL_TURTLE,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "满级路障分支：每个正在攻击它的敌人提供 5% 免伤，上限 50%",
			}
		Build.BARRICADE_THORNS:
			return {
				"name": "荆棘",
				"hotkey": "",
				"cost": BARRICADE_BRANCH_COST,
				"color": C_WALL_THORNS,
				"scene": "res://scenes/entities/wall.tscn",
				"desc": "满级路障分支：受到攻击时，对附近敌人反弹其最大生命值 0.5% 的伤害",
			}
		Build.DEATH:
			return {
				"name": "死神",
				"hotkey": "9",
				"cost": 2000.0,
				"color": C_DEATH,
				"scene": "res://scenes/entities/death_tower.tscn",
				"footprint": Vector2i(6, 6),
				"desc": "超级武器（6×6 占地，全图限一座）：全图索敌，炮弹秒杀 10×10 内非 Boss 敌人（Boss 受 5% 起，每级 +5%），留 15 秒核辐射（10%/秒）；3 级后可分支进化",
			}
		Build.DEATH_SILO:
			return {
				"name": "核弹井",
				"hotkey": "",
				"cost": DEATH_BRANCH_COST,
				"color": C_DEATH_SILO,
				"scene": "res://scenes/entities/death_tower.tscn",
				"footprint": Vector2i(6, 6),
				"desc": "死神分支：右键手动瞄准，3 分钟冷却；打击面积为初始死神的 6 倍，对 Boss 伤害 ×6",
			}
		Build.DEATH_FERRY:
			return {
				"name": "灵魂摆渡者",
				"hotkey": "",
				"cost": DEATH_BRANCH_COST,
				"color": C_DEATH_FERRY,
				"scene": "res://scenes/entities/death_tower.tscn",
				"footprint": Vector2i(6, 6),
				"desc": "死神分支：击杀收集灵魂（精英 2 / Boss 5 / 小怪 1），标题栏右键开火；每 100 灵魂计 1 次释放（灵魂不消耗），右键释放全场 20% 最大生命值冲击",
			}
	return {}


# ============================================================
#  建筑分类
# ============================================================
static func is_tower_kind(_kind: int) -> bool:
	## 所有建筑都属于塔的范畴（含围墙 / 金矿 / 改造车间与后续新增的建筑，自动适用）
	return true


## 会主动攻击的塔（敌人被围死时优先拆的目标；由 build_def 的 "weapon" 标记驱动，
## 后续新增会攻击的塔只需在其定义里加 "weapon": true）
static func is_weapon_tower(kind: int) -> bool:
	var def := build_def(kind)
	return not def.is_empty() and def.get("weapon", false)


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
