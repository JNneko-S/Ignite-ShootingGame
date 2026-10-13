extends Resource
class_name StageEvent
## ステージのタイムラインに並べるイベントの基底クラス。
## StageData の Events に追加するときは、SpawnEvent などの派生クラスを選ぶ。

## ステージ開始からの秒数。待機イベント(WaitClearEvent)の間は進まない。
## 並び順は自由で、StageRunner が時間順に並べ替えて実行する
@export var time : float = 0.0

## このイベントが実行される回数(SpawnEvent は count)
func unit_count() -> int:
	return 1

## unit_index 番目の実行時刻
func unit_time(_unit_index : int) -> float:
	return time

func execute(_runner : StageRunner, _unit_index : int) -> void:
	pass
