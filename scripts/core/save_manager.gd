extends Node
## 本地存档（单存档位）
##   · 只在「波次边界」自动写入 user://save_slot1.json —— 清空一波、进入下一波准备阶段时
##   · 开始界面「继续游戏」会读取存档并整局恢复：货币 / 词条 / 技能点 / 建筑（等级·血量·觉醒）/
##     矿山布局 / 角色位置 / 波次
##   · 波内进度（敌人 / 弹丸 / 特效 / 岩浆）不保存：中途退出只回到最近一次波次边界
##   · 通关（100 波）后删除存档；失败则保留，可从头再战最后一波

signal saved(wave: int)
signal loaded

const SAVE_PATH := "user://save_slot1.json"
const VERSION := 1

var _pending: Dictionary = {}   # 已请求读取、等待主场景应用的数据


# ============================================================
#  查询 / 删除
# ============================================================
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func read_save() -> Dictionary:
	## 读取并校验存档；版本不符或损坏时返回空字典（当作没有存档）
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档解析失败：%s" % SAVE_PATH)
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != VERSION:
		push_warning("存档版本不符（%d），已忽略" % int(d.get("version", 0)))
		return {}
	return d


func header() -> Dictionary:
	## 开始界面用的摘要：{wave, hero, saved_at}；无存档返回 {}
	var d := read_save()
	if d.is_empty():
		return {}
	return {
		"wave": int(d.get("wave", 0)),
		"hero": String(d.get("hero_id", "")),
		"saved_at": int(d.get("saved_at", 0)),
	}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ============================================================
#  写入：波次边界自动存档
# ============================================================
func autosave() -> bool:
	## 由波次调度在「本波清空、下一波准备开始」时调用
	if GameState.finished:
		return false
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm == null:
		return false
	var data := _collect(wm)
	if data.is_empty():
		return false
	if not _write(data):
		return false
	saved.emit(int(data["wave"]))
	return true


func _collect(wm) -> Dictionary:
	var seen := {}
	var buildings: Array = []
	for b in Board.buildings.values():
		if not is_instance_valid(b):
			continue
		if int(b.kind) == GameConfig.Build.PLANT:
			continue   # 植物炮塔是临时召唤物，不入档
		var id: int = b.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		buildings.append(b.to_save())

	var player = get_tree().get_first_node_in_group("player")
	var ppos: Array = [0.0, 0.0]
	var hero_cd := 0.0
	if player != null and is_instance_valid(player):
		ppos = [player.global_position.x, player.global_position.y]
		hero_cd = float(player.hero_cd)

	return {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"wave": int(wm.wave),
		# ---- 经济与养成 ----
		"gold": GameState.gold,
		"essence": GameState.essence,
		"skill_points": GameState.skill_points,
		"buff_levels": GameState.buff_levels.duplicate(),
		"affix_levels": GameState.affix_levels.duplicate(),
		"base_hp": GameState.base_hp,
		"base_hp_max": GameState.base_hp_max,
		"hero_id": GameState.hero_id,
		# ---- 地图与单位 ----
		"ores": Board.export_ores(),
		"buildings": buildings,
		"player": {"pos": ppos, "hero_cd": hero_cd},
	}


func _write(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("存档写入失败：%s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


# ============================================================
#  读取：开始界面请求 -> 主场景应用
# ============================================================
func request_load() -> bool:
	## 开始界面按下「继续游戏」时调用，主场景 _ready 里取走
	_pending = read_save()
	return not _pending.is_empty()


func clear_pending() -> void:
	_pending = {}


func take_pending() -> Dictionary:
	var d := _pending
	_pending = {}
	return d


func apply(data: Dictionary, main: Node) -> bool:
	## 把存档套回刚初始化的世界（Board.reset / GameState.reset 之后调用）
	if data.is_empty() or not data.has("buildings") or main == null:
		return false
	var root: Node = main.get_node_or_null("World/Buildings")
	var wm = get_tree().get_first_node_in_group("wave_manager")
	if root == null or wm == null:
		return false

	# ---- 经济与养成 ----
	GameState.gold = float(data.get("gold", GameConfig.START_GOLD))
	GameState.essence = int(data.get("essence", 0))
	GameState.skill_points = int(data.get("skill_points", 0))
	GameState.buff_levels = _int_array(data.get("buff_levels", []), 6)
	GameState.affix_levels = _int_array(data.get("affix_levels", []), 5)
	GameState.base_hp = float(data.get("base_hp", GameConfig.BASE_HP))
	GameState.base_hp_max = float(data.get("base_hp_max", GameConfig.BASE_HP))
	GameState.hero_id = String(data.get("hero_id", GameState.hero_id))
	GameState.recompute_bonuses()
	GameState.set_retool_menu(false)
	GameState.set_affix_shop(false)

	# ---- 矿山布局必须先恢复：金矿落点靠它判断是否为大金矿 ----
	Board.import_ores(data.get("ores", {}))

	# ---- 建筑 ----
	for bd in data.get("buildings", []):
		if typeof(bd) == TYPE_DICTIONARY:
			_spawn_building(bd, root)

	# ---- 角色 ----
	var pdata: Dictionary = data.get("player", {})
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var pos: Array = pdata.get("pos", [])
		if pos.size() == 2:
			player.global_position = Vector2(float(pos[0]), float(pos[1]))
		player.hero_cd = float(pdata.get("hero_cd", 0.0))
		if GameConfig.HEROES.has(GameState.hero_id):
			player.hero_id = GameState.hero_id

	# ---- 刷新 UI 并进入该波的准备阶段 ----
	GameState.broadcast()
	wm.restore(int(data.get("wave", 0)))
	loaded.emit()
	return true


func _spawn_building(bd: Dictionary, root: Node) -> void:
	var kind := int(bd.get("kind", -1))
	var def := GameConfig.build_def(kind)
	if def.is_empty():
		return
	var packed = load(String(def["scene"]))
	if packed == null:
		return
	var b = packed.instantiate()
	# 路障标记必须在 add_child 前设置：墙的 _ready 按它决定类型与血量
	b.barricade = bool(bd.get("barricade", false))
	root.add_child(b)
	var c: Array = bd.get("cell", [0, 0])
	b.place(Vector2i(int(c[0]), int(c[1])))
	if b.has_method("restore_from"):
		b.restore_from(bd)


func _int_array(src, size: int) -> Array:
	var out: Array = []
	for i in size:
		out.append(int(src[i]) if typeof(src) == TYPE_ARRAY and i < src.size() else 0)
	return out