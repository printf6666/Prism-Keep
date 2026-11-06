extends Node2D
## 入口：初始化单例数据、接上 UI 指令、驱动整局流程

@onready var waves: Node = $World/Waves


func _ready() -> void:
	randomize()
	InputSetup.ensure()
	Engine.time_scale = 1.0
	get_tree().paused = false

	# 重开一局时单例仍然存在，必须手动清空
	Board.reset()
	GameState.reset()

	GameState.speed_changed.connect(_on_speed_changed)
	GameState.game_finished.connect(_on_game_finished)

	# 从开始界面点「继续游戏」进来时优先套用存档，否则开新局
	var data := SaveManager.take_pending()
	if data.is_empty() or not SaveManager.apply(data, self):
		waves.begin()


func _on_speed_changed(mult: float) -> void:
	Engine.time_scale = mult


func _on_game_finished(win: bool) -> void:
	if win:
		SaveManager.delete_save()   # 通关后已经没有续档的意义
	# 稍等一下，让最后的爆散特效播完再定格
	await get_tree().create_timer(0.7).timeout
	get_tree().paused = true
