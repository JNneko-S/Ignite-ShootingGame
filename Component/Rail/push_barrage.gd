extends Node
class_name PushBarrage
## 列車のボスが、自機を「となりの援護の列車(中ボス列車)のほう」へ追いやる弾幕を撃つための部品。ボス(Enemy)の子に置く。
##   ・援護がいる側と反対へ、弾幕を傾けて撃つ(援護のいる側に逃げ道ができる)
##   ・援護がいないあいだは撃たない
##   ・Center Phase の段階からは、傾けずに撃つ(援護がいなくても撃つ。中央で戦う)
## 砲口(EnemyShooter)は、ボスの直下に置いて Shooters に入れる。位置は、画面の上から Heights の割合の高さ(列車のある範囲の中)に動かす。

## 押し出す弾幕を撃つ砲口
@export var shooters : Array[EnemyShooter] = []
## 砲口の高さ(画面の上から 0〜1)
@export var heights : Array[float] = [0.12, 0.3]
## 援護と反対の向きへ、弾幕をどれだけ傾けるか(度)
@export var turn_angle : float = 40.0
## この段階(0 から)からは、傾けずに、いつも撃つ。-1 ならしない
@export var center_phase : int = 2
## オンなら、Center Phase の前でも、援護がいなければ撃たない
@export var need_support : bool = true
## 援護のグループ(StageRunner が付ける「stage_ + タグ」)
@export var support_group : StringName = &"stage_support"

var _enemy : Enemy
var _mover : TrainBossMover
var _controller : BossPhaseController

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	for child in _enemy.get_children():
		if child is TrainBossMover:
			_mover = child
		elif child is BossPhaseController:
			_controller = child

func _physics_process(_delta : float) -> void:
	if _enemy == null or not is_instance_valid(_enemy) or not _enemy.is_inside_tree():
		return
	var view := CameraView.visible_rect(_enemy)
	var top := _enemy.global_position.y - 100000.0
	var bottom := _enemy.global_position.y + 100000.0
	if _mover and _mover._extent != Vector2.ZERO:
		top = _enemy.global_position.y + _mover._extent.x
		bottom = _enemy.global_position.y + _mover._extent.y
	var phase := _controller.current_phase() if _controller else 0
	var center := center_phase >= 0 and phase >= center_phase
	var side := _support_side()
	for i in shooters.size():
		var gun := shooters[i]
		if not is_instance_valid(gun):
			continue
		var h : float = heights[i % heights.size()] if not heights.is_empty() else 0.15
		gun.global_position = Vector2(_enemy.global_position.x, clampf(view.position.y + view.size.y * h, top, bottom))
		if center:
			gun.suppressed = false
			gun.turn_degrees = 0.0
		elif side == 0.0:
			gun.suppressed = need_support
			gun.turn_degrees = 0.0
		else:
			gun.suppressed = false
			# 正で左回り(画面の左へ)。援護が右なら左へ傾ける
			gun.turn_degrees = turn_angle * side

## いちばん近い援護が、ボスの右(1)か左(-1)か。いなければ 0
func _support_side() -> float:
	var best : Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(support_group):
		if not (node is Enemy) or not is_instance_valid(node) or node.hp_component == null or node.hp_component.hp <= 0:
			continue
		var leaving := false
		for child in node.get_children():
			if child is TrainBossMover and (child._leaving or not child.entered):
				leaving = true
		if leaving:
			continue
		var d := absf(node.global_position.x - _enemy.global_position.x)
		if d < best_d:
			best_d = d
			best = node
	if best == null:
		return 0.0
	return signf(best.global_position.x - _enemy.global_position.x)
