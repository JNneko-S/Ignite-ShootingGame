@tool
extends StageEvent
class_name WaitClearEvent
## 指定した敵が全滅するまで、ステージの進行を止める(中ボス・ボス用)。
## 待っている間、ステージの時間は進まない。全滅(または画面から消える)か、タイムアウトで再開する。

## SpawnEvent の tag。空なら、画面内の全ての敵が対象
@export var tag : String = ""
## 待つ時間の上限(秒)。0 なら上限なし。超えたら、倒せていなくても進行を再開する
@export var timeout : float = 0.0
## オンなら、通り過ぎる列車(Train。壊れた車両の残骸も)が画面からいなくなるまでも待つ(中ボスを出す前など)
@export var include_trains : bool = false
## 0 以上なら、難易度 ANOTHER のときは Timeout の代わりに、この秒数を上限にする(0 なら上限なし = 倒すまで待つ)。マイナスなら Timeout のまま
@export var another_timeout : float = -1.0

func execute(runner : StageRunner, _unit_index : int) -> void:
	var limit := another_timeout if HazardRank.active and another_timeout >= 0.0 else timeout
	runner.begin_wait(tag, limit, include_trains)
