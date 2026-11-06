extends Node
## 局外养成（自动加载单例：MetaManager）
##   · 星辉：局外货币 —— 击杀 Boss / 通关获得，入账立刻写盘，跨局永久
##   · 英雄升级：三位英雄各 3 条成长线，用星辉购买；基础值低于旧版数值，
##     升满后反超（成长曲线见 GameConfig.HERO_UPGRADES）
##   · 与局内存档相互独立：局内存档只记波次进度，英雄强度永远跟人走

signal souls_changed(value: int)
signal hero_upgraded(hero_id: String)

const META_PATH := "user://meta.json"
const META_VERSION := 1

var souls := 0
var hero_levels := {}   # hero_id -> Array[int]，与 GameConfig.HERO_UPGRADES 的成长线同序


func _ready() -> void:
	_load()


# ============================================================
#  星辉
# ============================================================
func add_souls(v: int) -> void:
	if v <= 0:
		return
	souls += v
	_save()
	souls_changed.emit(souls)


# ============================================================
#  英雄升级
# ============================================================
func hero_level(hero_id: String, track: int) -> int:
	var arr: Array = hero_levels.get(hero_id, [])
	return int(arr[track]) if track < arr.size() else 0


func hero_value(hero_id: String, track: int) -> float:
	## 当前数值 = 基础值 + 每级增量 × 等级（0 级即被削过的新基础值）
	var tracks: Array = GameConfig.HERO_UPGRADES.get(hero_id, [])
	if track >= tracks.size():
		return 0.0
	var def: Dictionary = tracks[track]
	return float(def["base"]) + float(def["step"]) * float(hero_level(hero_id, track))


func hero_value_text(hero_id: String, track: int) -> String:
	var tracks: Array = GameConfig.HERO_UPGRADES.get(hero_id, [])
	if track >= tracks.size():
		return ""
	return String(tracks[track]["fmt"]) % hero_value(hero_id, track)


func upgrade_cost(hero_id: String, track: int) -> int:
	## 从当前级升到下一级的星辉费用；已满级返回 -1
	var tracks: Array = GameConfig.HERO_UPGRADES.get(hero_id, [])
	if track >= tracks.size():
		return -1
	var lv := hero_level(hero_id, track)
	if lv >= int(tracks[track]["max_lv"]):
		return -1
	return GameConfig.HERO_UPGRADE_COST * (lv + 1)


func buy_upgrade(hero_id: String, track: int) -> bool:
	var tracks: Array = GameConfig.HERO_UPGRADES.get(hero_id, [])
	if track >= tracks.size():
		return false
	var cost := upgrade_cost(hero_id, track)
	if cost < 0 or souls < cost:
		return false
	if not hero_levels.has(hero_id):
		var arr := []
		for t in tracks.size():
			arr.append(0)
		hero_levels[hero_id] = arr
	souls -= cost
	hero_levels[hero_id][track] = hero_level(hero_id, track) + 1
	_save()
	souls_changed.emit(souls)
	hero_upgraded.emit(hero_id)
	return true


# ============================================================
#  持久化（user://meta.json）
# ============================================================
func _load() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("养成数据解析失败：%s" % META_PATH)
		return
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != META_VERSION:
		push_warning("养成数据版本不符（%d），已忽略" % int(d.get("version", 0)))
		return
	souls = int(d.get("souls", 0))
	hero_levels = {}
	var saved: Dictionary = d.get("hero_levels", {})
	for id in GameConfig.HERO_UPGRADES:
		var src = saved.get(id, [])
		var arr := []
		for t in GameConfig.HERO_UPGRADES[id].size():
			arr.append(int(src[t]) if typeof(src) == TYPE_ARRAY and t < src.size() else 0)
		hero_levels[id] = arr


func _save() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("养成数据写入失败：%s" % META_PATH)
		return
	f.store_string(JSON.stringify({
		"version": META_VERSION,
		"souls": souls,
		"hero_levels": hero_levels,
	}, "\t"))
	f.close()