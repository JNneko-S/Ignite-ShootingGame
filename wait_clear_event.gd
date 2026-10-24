@tool
extends StageEvent
class_name WaitClearEvent
## 指定した敵が全滅するまで、ステージの進行を止める(中ボス・ボス用)。
## 待っている間、ステージの時間は進まない。全滅(または画面から消える)か、タイムアウトで再開する。

## SpawnEvent の tag。空なら、画面内の全ての敵が対象
@export var tag : String = ""
## 待つ時間の上限(秒)。0 なら上限なし。超えたら、倒せていなくても進行を再開する
@export var timeout : float = 0.0

func execute(runner : StageRunner, _unit_index : int) -> void:
	runner.begin_wait(tag, timeout)
