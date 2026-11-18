extends Node
class_name BossShadowRush
## 大型機のボスの「強襲」の登場(ステージ3のブラックスワン -改-)。ボス(Enemy)の子に置く。
##   1. ボス自身の大きな影が、画面の下から上へ一気に通り過ぎる(ゴォーッ)
##   2. 少しして、ボスがアフターバーナーの炎を噴きながら、画面の上から一気に突っ込んできて止まる(ゴオン!)。
##      画面が揺れる。炎は見た目だけで、当たり判定はない
##   3. そのあとの攻撃の始まりは、ボスのステート(Intro の Duration)で決める
## 移動パターン(SpawnEvent の Move Pattern)は使わない(この部品が動かす)。

## 影の大きさ(ボスの何倍)・色・通り過ぎる時間(秒)・出始めるまでの時間(秒)
@export var shadow_scale : float = 1.6
@export var shadow_color : Color = Color(0.05, 0.0, 0.08, 0.45)
@export var shadow_time : float = 1.0
@export var shadow_delay : float = 0.3
## 影が通り過ぎてから、ボスが突っ込んでくるまでの時間(秒)
@export var rush_delay : float = 0.35
## 突っ込んでくる時間(秒)と、止まる高さ(画面の上から px)
@export var rush_time : float = 1.1
## 突っ込んでくるあいだの炎の強さ(0〜1。見た目だけで当たらない)
@export var rush_flame : float = 0.6
@export var arrive_y : float = 125.0
## 止まったときの画面の揺れ(px)と、揺れる時間(秒)
@export var arrive_shake : float = 14.0
@export var arrive_shake_time : float = 0.7
## 影が通るときの音と、止まったときの音(空なら鳴らさない)
@export var pass_sound : AudioStream
@export var arrive_sound : AudioStream

var _enemy : Enemy

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("BossShadowRush: 親が Enemy ではありません")
		return
	_enemy.pattern = null # 移動パターンは使わない(親の _ready より先に呼ばれる)
	_run.call_deferred()

func _run() -> void:
	if not is_instance_valid(_enemy):
		return
	var tree := get_tree()
	var view := CameraView.visible_rect(_enemy)
	var x := view.get_center().x
	# ボスは、画面の上の外で待つ
	_enemy.global_position = Vector2(x, view.position.y - 260.0)
	await tree.create_timer(shadow_delay, false).timeout
	# 1. 影が、下から上へ通り過ぎる
	var shadow := _make_shadow()
	if shadow:
		tree.current_scene.add_child(shadow)
		shadow.global_position = Vector2(x, view.end.y + 260.0 * shadow_scale)
		_play(pass_sound, -4.0, 0.8)
		var pass_tween := shadow.create_tween()
		pass_tween.tween_property(shadow, "global_position:y", view.position.y - 260.0 * shadow_scale, shadow_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pass_tween.tween_callback(shadow.queue_free)
		var camera := StageCamera.of(_enemy)
		if camera:
			camera.shake(3.0, shadow_time) # 頭の上を通る、低い揺れ
		await pass_tween.finished
	await tree.create_timer(rush_delay, false).timeout
	if not is_instance_valid(_enemy):
		return
	# 2. 炎を噴きながら、上から一気に突っ込んできて、止まる
	view = CameraView.visible_rect(_enemy)
	var arrive := view.position.y + arrive_y
	var dive := _dive()
	if dive:
		dive.show_flame(rush_flame)
	var rush := _enemy.create_tween()
	rush.tween_property(_enemy, "global_position", Vector2(x, arrive + 18.0), rush_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await rush.finished
	if not is_instance_valid(_enemy):
		return
	_on_arrive()
	var settle := _enemy.create_tween()
	settle.tween_property(_enemy, "global_position:y", arrive, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 止まったら、炎がしぼんで消える
	if dive:
		var fade := _enemy.create_tween()
		fade.tween_method(dive.show_flame, rush_flame, 0.0, 0.6)

func _dive() -> AfterburnerDive:
	for child in _enemy.get_children():
		if child is AfterburnerDive:
			return child
	return null

## 止まった瞬間: ゴオン!(画面が揺れる)
func _on_arrive() -> void:
	var camera := StageCamera.of(_enemy)
	if camera:
		camera.shake(arrive_shake, arrive_shake_time)
	SpriteShake.shake(_enemy, 6.0)
	_play(arrive_sound, -2.0, 0.7)

## ボスの絵(直下の Sprite2D)を写した、黒い影
func _make_shadow() -> Node2D:
	var root := Node2D.new()
	root.z_as_relative = false
	root.z_index = -12 # 空と雲の背景(-20)より手前、敵や弾より奥
	root.scale = Vector2.ONE * shadow_scale
	var count := 0
	for child in _enemy.get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var copy := Sprite2D.new()
		copy.texture = sprite.texture
		copy.hframes = sprite.hframes
		copy.vframes = sprite.vframes
		copy.frame = sprite.frame
		copy.offset = sprite.offset
		copy.centered = sprite.centered
		copy.position = sprite.position
		copy.rotation = sprite.rotation
		copy.scale = sprite.scale
		copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		copy.modulate = shadow_color
		root.add_child(copy)
		count += 1
	if count == 0:
		root.free()
		return null
	return root

func _play(stream : AudioStream, volume_db : float, pitch : float) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
