extends Node
class_name LeaderLink
## 親分がいなくなったら、持ち主の敵(この部品の親)も、撃つのをやめて消える。
## ブラッドスワンが呼ぶ翼のブラックスワンズのように、親分のそばでだけ働く敵に付ける。
## 親分は Leader Group のグループに入れておく(倒されても、画面の外へ去っても、いなくなったら消える)

## 親分のグループ
@export var leader_group : StringName = &"blood_swan"
## 出てから、親分を探し始めるまでの時間(秒)
@export var grace : float = 1.5
## 消えるまでの時間(秒。薄くなって消える)
@export var fade_time : float = 0.7

var _age : float = 0.0
var _check_in : float = 0.0
var _leaving : bool = false

func _physics_process(delta : float) -> void:
	if _leaving:
		return
	_age += delta
	_check_in -= delta
	if _age < grace or _check_in > 0.0:
		return
	_check_in = 0.3
	for node in get_tree().get_nodes_in_group(leader_group):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return
	_leave()

## 撃つのをやめて、薄くなって消える(倒した扱いにはしない)
func _leave() -> void:
	_leaving = true
	var owner_enemy := get_parent() as Node2D
	if owner_enemy == null:
		return
	for node in owner_enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			(node as EnemyShooter).enabled = false
	var tween := owner_enemy.create_tween()
	tween.tween_property(owner_enemy, "modulate:a", 0.0, fade_time)
	tween.tween_callback(owner_enemy.queue_free)
