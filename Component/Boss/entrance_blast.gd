extends Node
class_name EntranceBlast
## ボスの登場の大爆発。ボスの子に置く。ボスが出現した瞬間に、画面の上の端が大爆発し、画面が揺れる。
## 登場の間(Hold Fire Time)は撃たせず、そのあと今の段階の弾幕で撃ち始める。
## ボスは画面の上の外から出てくるようにしておく(移動パターンの Start Position を画面の上の外に)。
## 爆発は地上の敵と同じ層なので、爆煙の下からボスが現れる。

## 出現してから爆発するまでの時間(秒)
@export var delay : float = 0.0
## 真ん中の大爆発の大きさ
@export var main_scale : float = 5.0
## 上の端に並ぶ爆発の数と、全部が起きるまでの時間(秒)
@export var chain_count : int = 14
@export var chain_duration : float = 1.0
## 並ぶ爆発を起こす範囲(画面の上の端から下へ、px)
@export var chain_depth : float = 90.0
## 画面の揺れの強さ(px)と時間(秒)。0 なら揺らさない
@export var shake_strength : float = 10.0
@export var shake_time : float = 1.2
## 爆発の効果音(シーンに置いた AudioStreamPlayer)
@export var sound : AudioStreamPlayer
## 出現してから、この時間(秒)は撃たない。勢いよく前に出てくるあいだは撃たず、下がり始めてから撃ち始める
@export var hold_fire_time : float = 1.25

func _ready() -> void:
	_play.call_deferred()
	_hold_fire.call_deferred()

## 登場の間は撃たせず、時間が来たら、今の段階の弾幕で撃ち始める
func _hold_fire() -> void:
	if hold_fire_time <= 0.0:
		return
	var boss := get_parent()
	var shooters : Array[EnemyShooter] = []
	for node in boss.find_children("*", "", true, false):
		if node is EnemyShooter:
			shooters.append(node)
			node.stop()
	await get_tree().create_timer(hold_fire_time).timeout
	if not is_instance_valid(boss) or (boss is Enemy and boss._is_dead):
		return
	var controller : BossPhaseController = null
	for child in boss.get_children():
		if child is BossPhaseController:
			controller = child
	for shooter in shooters:
		if not is_instance_valid(shooter) or not shooter.enabled:
			continue
		if shooter.has_phases():
			shooter.set_phase(controller.current_phase() if controller else 0)
		else:
			shooter.set_patterns(shooter.patterns, shooter.sequence)

func _play() -> void:
	var tree := get_tree()
	if delay > 0.0:
		await tree.create_timer(delay).timeout
	var view := CameraView.visible_rect(get_parent() as Node2D)
	var top := view.position.y
	# 真ん中の大爆発
	var center := Vector2(view.get_center().x, top + chain_depth * 0.4)
	Explosion.spawn(tree, Explosion.EXPLOSIVE, center, main_scale)
	Explosion.spawn(tree, Explosion.WAVE, center, main_scale * 0.8)
	if sound:
		SoundManager.play(sound)
	_shake(tree)
	# 上の端に沿って、左右へ広がるように爆発が続く(どのノードにも紐づかない Tween で進める)
	var tween := tree.create_tween()
	var interval := chain_duration / maxi(chain_count, 1)
	for i in chain_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := float(i + 1) / float(chain_count) # 後ほど外側へ
		var at := Vector2(center.x + side * spread * view.size.x * 0.5 * randf_range(0.7, 1.0),
			top + randf() * chain_depth)
		var scene : PackedScene = Explosion.ALL[i % Explosion.ALL.size()]
		var effect_scale := randf_range(2.0, 3.5) * (0.6 if scene == Explosion.WAVE else 1.0)
		tween.tween_callback(func() -> void: Explosion.spawn(tree, scene, at, effect_scale))
		tween.tween_interval(interval)

## カメラを揺らす(だんだん弱くなる)
func _shake(tree : SceneTree) -> void:
	if shake_strength <= 0.0 or shake_time <= 0.0:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var base := camera.offset
	var tween := tree.create_tween()
	tween.tween_method(func(t : float) -> void:
		if is_instance_valid(camera):
			var power := shake_strength * (1.0 - t)
			camera.offset = base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * power,
		0.0, 1.0, shake_time)
	tween.tween_callback(func() -> void:
		if is_instance_valid(camera):
			camera.offset = base)
