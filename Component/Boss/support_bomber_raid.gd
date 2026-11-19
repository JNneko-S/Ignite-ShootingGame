extends Node
class_name SupportBomberRaid
## (ANOTHER)2面ボスの追加ギミック。ボス(Enemy)の子に置く。
## 左右の画面に呼ばれた援護の列車(中ボス列車。Support Tag の敵)がいる画面に、自機(カメラ)がいるあいだ、
## 3面の爆撃機が、横3列で端から端まで飛んでくる(上下に弾を撃つ)。その画面にいるかぎり、Interval 秒ごとに来続ける。

## 援護の列車の tag(StageRunner の register_tag。グループは "stage_" + tag)
@export var support_tag : String = "support"
## 飛んでくる爆撃機・その動き・その弾幕
@export var bomber_scene : PackedScene = preload("res://GameScene/Enemy/Sky/bomber.tscn")
@export var move_pattern : MovePattern = preload("res://Resources/MovePatterns/Stage3/m3_bomber_sweep.tres")
@export var shot_pattern : ShotPattern = preload("res://Resources/ShotPatterns/Stage3/s3_bomber_updown.tres")
## 1回に来る列の数(縦に Row Step px ずつずらす)と、1機ずつの時間差(秒)
@export var rows : int = 3
@export var row_step : float = 80.0
@export var row_interval : float = 0.45
## 次の爆撃機の列が来るまでの間隔(秒)
@export var interval : float = 2.6

var _boss : Enemy
var _flip : bool = false

func _ready() -> void:
	_boss = get_parent() as Enemy
	if _boss == null or not HazardRank.active:
		return
	_loop.call_deferred()

func _alive() -> bool:
	return is_instance_valid(_boss) and _boss.is_inside_tree() and not _boss._is_dead

func _loop() -> void:
	while _alive():
		await get_tree().create_timer(interval, false).timeout
		if not _alive():
			return
		# 援護が出てくる演出のあいだ(敵が撃たない・自機が止まっている)は、出さない
		if EnemyShooter.is_holding_fire():
			continue
		var lane := _lane_with_support()
		if lane >= 0:
			_send(lane)

## 自機(カメラ)が今いる画面に、援護の列車がいれば、その画面の番号。いなければ -1
func _lane_with_support() -> int:
	var camera := StageCamera.of(_boss)
	if camera == null:
		return -1
	var view_lane := _nearest_lane(camera, CameraView.visible_rect(_boss).get_center().x)
	for support in get_tree().get_nodes_in_group("stage_" + support_tag):
		var node := support as Node2D
		if node == null or not node.is_inside_tree():
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if _nearest_lane(camera, node.global_position.x) == view_lane and view_lane != 1:
			return view_lane
	return -1

func _nearest_lane(camera : StageCamera, x : float) -> int:
	var best := 0
	for i in camera.lanes.size():
		if absf(camera.lane_x(i) - x) < absf(camera.lane_x(best) - x):
			best = i
	return best

## その画面に、爆撃機の横の列を Rows 本、時間差で出す(1回ごとに、左から・右からを入れ替える)
func _send(lane : int) -> void:
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner == null:
		return
	var event := SpawnEvent.new()
	event.enemy_scene = bomber_scene
	event.move_pattern = move_pattern
	var pats : Array[ShotPattern] = [shot_pattern]
	event.shot_patterns = pats
	event.count = rows
	event.interval = row_interval
	event.offset_step = Vector2(0.0, row_step)
	event.camera_lane = lane
	event.mirror_x = _flip
	_flip = not _flip
	for i in rows:
		if not _alive():
			return
		runner.spawn(event, i)
		await get_tree().create_timer(row_interval, false).timeout
