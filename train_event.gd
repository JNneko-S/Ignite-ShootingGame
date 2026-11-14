@tool
extends StageEvent
class_name TrainEvent
## 線路の上に列車(Train)を走らせる。
## 列車のシーン(GameScene/Train/ の .tscn。ルートが Train)を選び、走る線路・速さ・車両の数を上書きできる。

## 列車のシーン(ルートが Train)
@export var train_scene : PackedScene = preload("res://GameScene/Train/passing_train.tscn")
## 走る線路(ステージ2は 0〜11。0〜3 = 左の画面 / 4〜7 = 中央 / 8〜11 = 右。
## 束の左の線路(偶数)は上へ、右の線路(奇数)は下へ走る)
@export var rail : int = 4
## 線路に沿った速さ(px/秒)。0 なら列車のシーンの値。
## 向きは線路で決まる(左の線路 = 偶数は上へ、右の線路 = 奇数は下へ)ので、大きさだけを入れる
@export var speed : float = 0.0
## 車両の数。0 なら列車のシーンの値
@export var car_count : int = 0
## 車両に付ける tag(WaitKillsEvent / WaitClearEvent が数える)
@export var tag : String = "train"
## 同じ列車を何本出すか(Interval 秒おき、Rail Step ずつ線路をずらす)
@export var count : int = 1
@export var interval : float = 2.0
@export var rail_step : int = 0

func unit_count() -> int:
	return maxi(count, 1)

func unit_time(unit_index : int) -> float:
	return time + interval * unit_index

func execute(runner : StageRunner, unit_index : int) -> void:
	if train_scene == null:
		return
	var train := train_scene.instantiate() as Train
	if train == null:
		push_error("TrainEvent: train_scene のルートが Train ではありません")
		return
	train.rail = rail + rail_step * unit_index
	if speed != 0.0:
		train.speed = speed
	if car_count > 0:
		train.car_count = car_count
	train.tag = tag
	var parent : Node = runner.enemy_parent if runner.enemy_parent else runner.get_tree().current_scene
	parent.add_child(train)
