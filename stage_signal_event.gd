@tool
extends StageEvent
class_name StageSignalEvent
## StageRunner の stage_signal を出す。WARNING表示、BGM切り替え、ステージ名の表示など、
## ステージ側の演出を、タイムライン上の好きな位置から呼ぶために使う。

## 受け取る側が見分けるための名前(例: warning, bgm_boss, stage_title)
@export var signal_name : String = ""
## 表示する文字などを渡したいとき
@export var text : String = ""

func execute(runner : StageRunner, _unit_index : int) -> void:
	runner.emit_stage_signal(signal_name, text)
