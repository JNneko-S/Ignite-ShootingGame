extends Node
## 開発用: 3面を動かしたまま、SceneSwitcher で4面へ切り替えて、そのまま流す(切り替えで落ちないかを見る)。
##   godot --headless --path . --fixed-fps 60 res://tools/transition_test.tscn -- [秒数]
var _keeper : Node

func _ready() -> void:
	DebugTools.used = true # テストのプレイは、実績もスコアも保存しない(遊んでいる人のセーブを汚さない)
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 60.0
	# ステージが切り替わっても残る見張り役(自機を無敵にして、時間が来たら終える)
	_keeper = Node.new()
	_keeper.set_script(_KEEPER)
	_keeper.set("until", seconds)
	get_tree().root.add_child.call_deferred(_keeper)
	add_child((load("res://stage3.tscn") as PackedScene).instantiate())
	await get_tree().create_timer(4.0).timeout
	print("SWITCH to stage4")
	SceneSwitcher.change("res://stage4.tscn")

const _KEEPER := preload("res://tools/transition_keeper.gd")
