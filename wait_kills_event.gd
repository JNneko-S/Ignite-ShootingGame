@tool
extends StageEvent
class_name WaitKillsEvent
## tag の敵を Kills 体倒すまで、ステージの進行を止める(「ある程度倒したら次へ」)。
## 待っている間、ステージの時間は進まないので、そのあいだ出し続けるもの(通り過ぎる列車、雑魚の波)は
## Loop Events に入れる。Loop Events の Time は「待ち始めてからの秒数」で、Loop Length 秒ごとに頭から繰り返す。

## 数える敵の tag(SpawnEvent / TrainEvent の Tag)
@export var tag : String = ""
## この数だけ倒したら、進行を再開する(待ち始めてから倒した数)
@export var kills : int = 10
## 待つ時間の上限(秒)。0 なら上限なし
@export var timeout : float = 0.0
## 待っているあいだ繰り返すイベント(Time は待ち始めてからの秒数)
@export var loop_events : Array[StageEvent] = []
## Loop Events を頭から繰り返す間隔(秒)
@export var loop_length : float = 8.0

func execute(runner : StageRunner, _unit_index : int) -> void:
	runner.begin_kill_wait(self)
