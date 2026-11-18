@tool
extends Resource
class_name StageData
## 1ステージ分のタイムライン。.tres で保存して、StageRunner に割り当てる。

@export var stage_name : String = "Stage 1"
## イベントの並び。順番は自由(time の小さい順に実行される)
@export var events : Array[StageEvent] = []
## 難易度 ANOTHER のときだけ、events に足して実行するイベント(敵の追加など)
@export var another_events : Array[StageEvent] = []
## ANOTHER で、ランクによって雑魚の撃つ頻度が上がる量の割合(1 でそのまま、0.5 なら半分だけ上がる)。
## 雑魚の弾がもともと多いステージで下げる
@export var another_zako_rate_ratio : float = 1.0

@export_group("パワーアップ")
## オフなら、雑魚(ItemDrop を持つ敵)はパワーアップを落とさない(列車の全車両撃破で落とすステージなど)
@export var zako_power_drops : bool = true
## 空でなければ、通り過ぎる列車の全車両を壊したときに、このアイテムを落とす
@export var train_clear_power_up : PackedScene
## 列車の全車両撃破でアイテムを落としたあと、次に落とせるまでの時間(秒)。落ちる間隔をそろえるため
@export var train_clear_power_interval : float = 12.0
