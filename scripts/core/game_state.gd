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
signal skill_changed(value: int)     # 技能点变化
signal retool_menu_toggled(open: bool)
signal enemy_killed(type: String)    # 敌人被击杀（灵魂摆渡者收集灵魂）
signal essence_changed(value: int)   # 晶源变化
signal affix_changed                 # 词条等级变化
signal affix_shop_toggled(open: bool)

var gold := 0.0
var base_hp := 0.0
var base_hp_max := 0.0
var wave := 0
var total_waves := GameConfig.TOTAL_WAVES
var finished := false

# ---- 技能点与改造车间全局加成 ----
var skill_points := 0
var buff_levels: Array = [0, 0, 0, 0, 0, 0]
var building_dmg_mul := 1.0  # 加成 1：所有建筑攻击力倍率（全部会攻击的建筑 / 分支塔）
var wall_hp_mul := 1.0       # 加成 2：围墙 / 路障血量倍率
var mine_income_bonus := 0.0 # 加成 3：金矿每次产出额外金币
var burn_bonus := 0.0        # 加成 4：灼烧额外比例（岩浆中翻倍）
var retool_menu_open := false
var hero_id := "flame_fist"   # 开始界面选择的英雄

# ---- 晶源与基地词条（靠近大本营按 B 购买，五条词条各作用于一个塔系） ----
var essence := 0
var affix_levels: Array = [0, 0, 0, 0, 0]
var affix_shop_open := false
var cannon_dmg_mul := 1.0   # 词条 1：炮塔系伤害倍率
var arrow_haste := 1.0      # 词条 3：箭塔系攻速倍率（冷却流逝）
var effect_mul := 1.0       # 词条 4：寒冰 / 喷火特效强度倍率


func reset() -> void:
	gold = GameConfig.START_GOLD
	base_hp = GameConfig.BASE_HP
	base_hp_max = GameConfig.BASE_HP
	wave = 0
	total_waves = GameConfig.TOTAL_WAVES
	finished = false
	skill_points = 0
	buff_levels = [0, 0, 0, 0, 0, 0]
	building_dmg_mul = 1.0
	wall_hp_mul = 1.0
	mine_income_bonus = 0.0
	burn_bonus = 0.0
	retool_menu_open = false
	essence = 0
	affix_levels = [0, 0, 0, 0, 0]
	affix_shop_open = false
	cannon_dmg_mul = 1.0
	arrow_haste = 1.0
	effect_mul = 1.0
	gold_changed.emit(gold)
	base_changed.emit(base_hp, base_hp_max)
	wave_changed.emit(wave, total_waves)
	skill_changed.emit(skill_points)
	essence_changed.emit(essence)
	affix_changed.emit()


func add_gold(v: float) -> void:
	if finished:
		return
	gold += v
	gold_changed.emit(gold)


func add_essence(v: int) -> void:
	## 怪物死亡掉落晶源
	if finished:
		return
	essence += v
	essence_changed.emit(essence)


func add_skill_points(v: int) -> void:
	if finished:
		return
	skill_points += v
	skill_changed.emit(skill_points)


func buff_level(i: int) -> int:
	return buff_levels[i]


func has_dire_straits() -> bool:
	## 水深火热科技是否已解锁（冰暴减速 × 岩浆 → 负面翻倍 + 虚弱）
	return buff_levels[4] > 0


func buy_buff(i: int) -> bool:
	## 用技能点购买改造车间加成 / 技能，返回是否成功
	var def: Dictionary = GameConfig.RETOOL_BUFFS[i]

	# 动作类（灭世）：不升级、可无限次使用，每次消耗固定技能点
	if def.get("action", false):
		var tower = find_death_tower()
		if tower == null:
			notice.emit("需要先建造死神塔")
			return false
		var acost: int = GameConfig.buff_cost(i, 0)
		if skill_points < acost:
			return false
		skill_points -= acost
		buff_levels[i] += 1   # 记录使用次数
		tower.fire_apocalypse()
		skill_changed.emit(skill_points)
		return true

	var lv: int = buff_levels[i]
	if lv >= int(def["max_lv"]):
		return false
	var cost: int = GameConfig.buff_cost(i, lv)
	if skill_points < cost:
		return false
	skill_points -= cost
	buff_levels[i] = lv + 1
	match i:
		0:
			building_dmg_mul = 1.0 + 0.1 * buff_levels[0]
		1:
			# 墙体总倍率 = 1 + 20% ×（改造车间等级 + 基地词条等级）；按比例回补已建成墙体
			var new_mul: float = 1.0 + 0.2 * buff_levels[1] + 0.2 * affix_levels[1]
			var ratio: float = new_mul / wall_hp_mul
			for b in Board.buildings.values():
				if is_instance_valid(b) and b.is_wall:
					b.max_hp *= ratio
					b.hp = minf(b.hp * ratio, b.max_hp)
			wall_hp_mul = new_mul
		2:
			mine_income_bonus = buff_levels[2] * 0.5
		3:
			burn_bonus = buff_levels[3] * 0.005
	skill_changed.emit(skill_points)
	return true


## 场上唯一的死神塔（死神 / 核弹井 / 灵魂摆渡者）
func find_death_tower():
	for b in Board.buildings.values():
		if not is_instance_valid(b):
			continue
		var k := int(b.kind)
		if k == GameConfig.Build.DEATH or k == GameConfig.Build.DEATH_SILO \
				or k == GameConfig.Build.DEATH_FERRY:
			return b
	return null


func set_retool_menu(open: bool) -> void:
	if retool_menu_open == open:
		return
	retool_menu_open = open
	retool_menu_toggled.emit(open)


# ============================================================
#  晶源词条：靠近大本营按 B 打开商店，用晶源购买（每条词条各作用于一个塔系）
# ============================================================
func affix_level(i: int) -> int:
	return affix_levels[i]


func set_affix_shop(open: bool) -> void:
	if affix_shop_open == open:
		return
	affix_shop_open = open
	affix_shop_toggled.emit(open)


func buy_affix(i: int) -> bool:
	## 用晶源购买 / 升级词条，返回是否成功
	var lv: int = affix_levels[i]
	if lv >= int(GameConfig.AFFIXES[i]["max_lv"]):
		return false
	var cost: int = GameConfig.affix_cost(i, lv)
	if essence < cost:
		return false
	essence -= cost
	essence_changed.emit(essence)
	affix_levels[i] = lv + 1
	match i:
		0:
			cannon_dmg_mul = 1.0 + 0.15 * affix_levels[0]
		1:
			# 与改造车间围墙加成同乘：重算总倍率并按比例回补已建成墙体
			var new_mul: float = 1.0 + 0.2 * buff_levels[1] + 0.2 * affix_levels[1]
			var ratio: float = new_mul / wall_hp_mul
			for b in Board.buildings.values():
				if is_instance_valid(b) and b.is_wall:
					b.max_hp *= ratio
					b.hp = minf(b.hp * ratio, b.max_hp)
			wall_hp_mul = new_mul
		2:
			arrow_haste = 1.0 + 0.1 * affix_levels[2]
		3:
			effect_mul = 1.0 + 0.2 * affix_levels[3]
		4:
			pass   # 辐射延时：死神发射炮弹时读取 radiation_time() 现算
	affix_changed.emit()
	return true


## 死神系核辐射持续时间：基础 15 秒 + 辐射词条每级 4 秒（灭世的 20 秒不受词条影响）
func radiation_time() -> float:
	return GameConfig.DEATH_RADIATION_TIME + 4.0 * float(affix_levels[4])


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
