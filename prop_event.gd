@tool
extends StageEvent
class_name PropEvent
## 背景のオブジェクト(IgniteTarget など)を、画面の上の端のすぐ外に出す。
## 背景のスプライトの子にするので、背景と一緒に流れて、揺れる。
## count を 2 以上にすると、縦につながった列(貨車の編成など)になる。

@export var scene : PackedScene = preload("res://GameScene/Prop/ignite_target.tscn")
## 親にするノード(ステージのルートから)。背景のスプライトにする
@export var parent_path : NodePath = ^"Scroller/Sprite2D"
## 親の中での横の位置(背景のテクスチャの px、中心が 0)。
## Train Stage の線路は、およそ -74 / -28 / 42 / 66
@export var local_x : float = -74.0
## 縦に並べる数と、間隔(背景のテクスチャの px)
@export var count : int = 1
@export var spacing : float = 58.0

func execute(runner : StageRunner, _unit_index : int) -> void:
	runner.spawn_prop(self)
