extends Node
## 開発用: タイトル画面で「Another Round」の合図を見る(二周目へ進む直前まで)。
##   godot --path . res://tools/preview_another_round.tscn
func _ready() -> void:
	RunConfig.loop = 2
	TitleScreen.another_round_pending = true
	get_tree().change_scene_to_file.call_deferred("res://title.tscn")
