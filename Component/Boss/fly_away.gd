extends Node
class_name FlyAway
## ボスの「顔見せ」用の部品(ステージ3の冒頭のブラックスワン -改-)。ボス(Enemy)の子に置く。
##   1. 出てきてから Stay Time 秒のあいだは、いつもどおり撃ってくる(撃たれても倒れない)
##   2. 時間がたつと撃つのをやめ、自機と反対側へ、機体を少し傾けながら(自機と同じロールの見せ方)斜め上へ飛び去る
##   3. 画面の外に出たら消える(倒したことにはならない)

## 撃ち合う時間(秒。出てきてから数える)
@export var stay_time : float = 9.0
## 飛び去る時間(秒)と、横へ動く距離(px)
@export var leave_time : float = 2.4
@export var leave_side : float = 340.0
## 飛び去るときの傾き: ロール(機体を横に倒す。度。横幅が cos 倍に縮む)と、回転(度)
@export var bank_roll : float = 30.0
@export var bank_angle : float = 6.0
## 撃たれても HP がこれより減らないようにする割合(0.9 なら、9割より下には減らない)
@export var min_hp_ratio : float = 0.9

var _enemy : Enemy
var _leaving : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_run.call_deferred()

func _physics_process(_delta : float) -> void:
	# 顔見せのあいだは倒れない
	if _enemy and is_instance_valid(_enemy) and _enemy.hp_component:
		var floor_hp := int(_enemy.hp_component.max_hp * min_hp_ratio)
		if _enemy.hp_component.hp < floor_hp:
			_enemy.hp_component.hp = floor_hp

func _run() -> void:
	await get_tree().create_timer(stay_time, false).timeout
	if not is_instance_valid(_enemy) or _leaving:
		return
	_leaving = true
	# 撃つのも動くのもやめる(ステート・動き回りを止める。炎の位置合わせのため、AfterburnerDive は止めない)
	# 動き回りの途中の移動も止める(FighterMover の移動はボスに付いた tween なので、部品を止めても動き続ける)
	_enemy.set_meta(&"hold_position", true)
	for child in _enemy.get_children():
		if child.name in ["StateMachine", "FighterMover"]:
			child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is FighterMover and child._tween and child._tween.is_valid():
			child._tween.kill()
		if child is BossScrollBoost:
			child._on_died(_enemy) # 背景の速さを元に戻す
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			node.stop()
			node.enabled = false
	var hurtbox := _enemy.get_node_or_null("Hurtbox")
	if hurtbox:
		for shape in hurtbox.find_children("*", "CollisionShape2D", false, false):
			shape.set_deferred("disabled", true)
	_enemy.remove_from_group("enemy") # 全滅を待つイベントを止めない
	# アフターバーナー突撃の途中なら、終わるまで待つ(突撃の動きと、飛び去る動きがぶつからないように)
	var dive : AfterburnerDive = null
	for child in _enemy.get_children():
		if child is AfterburnerDive:
			dive = child
	var waited := 0.0
	while dive and dive.is_diving() and waited < 8.0 and is_instance_valid(_enemy):
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if not is_instance_valid(_enemy):
		return
	var view := CameraView.visible_rect(_enemy)
	var radius := _extent()
	# 自機と反対側へ、斜め上に抜けていく(機体全体が画面の外に出る高さまで)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var side := 1.0
	if player and player.global_position.x > _enemy.global_position.x:
		side = -1.0
	var target := Vector2(_enemy.global_position.x + side * leave_side, view.position.y - radius - 40.0)
	_bank(side)
	var tween := _enemy.create_tween().set_parallel(true)
	tween.tween_property(_enemy, "global_position:x", target.x, leave_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_enemy, "global_position:y", target.y, leave_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_enemy, "rotation", deg_to_rad(bank_angle) * side, leave_time * 0.5).set_trans(Tween.TRANS_SINE)
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(3.0, 0.6)
	await tween.finished
	# 念のため、機体のどこかがまだ画面に映っていたら、映らなくなるまで上へ進めてから消す(パッと消えないように)
	while is_instance_valid(_enemy) and CameraView.visible_rect(_enemy).grow(radius).has_point(_enemy.global_position):
		await get_tree().physics_frame
		_enemy.global_position.y -= 600.0 * get_physics_process_delta_time()
	if is_instance_valid(_enemy):
		_enemy.queue_free()

## 機体の大きさ(中心から、いちばん遠い絵の端までの距離 px)
func _extent() -> float:
	var radius := 120.0
	for child in _enemy.get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var frame := Vector2(sprite.texture.get_width() / float(maxi(sprite.hframes, 1)), sprite.texture.get_height() / float(maxi(sprite.vframes, 1)))
		var half := frame * sprite.scale.abs() * _enemy.scale.abs() * 0.5 + sprite.position.abs()
		radius = maxf(radius, half.length())
	return radius

## 機体を、進む向きへ少しずつ横に倒して見せる(横幅を少し縮めると、横に倒れたように見える)。
## ボスの絵は大きなコマの絵を何枚も重ねているので、シェーダーではなく、機体全体の横幅で表す
func _bank(_side : float) -> void:
	var tween := _enemy.create_tween()
	tween.tween_property(_enemy, "scale:x", cos(deg_to_rad(bank_roll)), leave_time * 0.5).set_trans(Tween.TRANS_SINE)
