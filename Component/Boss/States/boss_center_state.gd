extends BossState
class_name BossCenterState
## ボスが決まった場所(画面の中央など)まで出てきて、止まったまま、段階ごとの弾幕を撃つステート。
## ほかの弾幕とは一緒に撃たない(入ったときに全ての砲口を止める)。動いているあいだは撃たない。
##
## 連携(Wing Scene): Wing From Phase 以降の段階では、着いたところで仲間(Wing Scene)を Wing Offsets の場所に呼ぶ。
## 仲間は自分の移動パターンで入ってきて、自分の弾幕を撃ち、このステートが終わると帰っていく。
## 例) ブラックスワン改が画面の中央に来て、両脇にブラックスワンズを呼び、縦の弾の壁で画面を区切らせ、
##     そのあいだを自分の弾幕で掃く(連携攻撃)
##
## 撃ち終わったら Next State(ANOTHER なら Another Next State)へ移る。元の場所へは、FighterMover が戻す。

## 撃つ砲口
@export var shooter : EnemyShooter
## 段階ごとの弾幕(第一形態から。足りなければ最後のもの)。1つの段階に1つの弾幕
@export var patterns : Array[ShotPattern] = []
## 出ていく場所(画面の中での割合。(0.5, 0.42) なら、横の真ん中、上から 42%)
@export var target_ratio : Vector2 = Vector2(0.5, 0.42)
## 出ていくのにかける時間(秒)と、着いてから撃ち始めるまでの間(秒)
@export var move_time : float = 1.2
@export var settle_time : float = 0.5
## 撃っている時間(秒)。撃ち終わってから、この時間だけ待って次へ(弾が流れていくのを待つ)
@export var fire_time : float = 7.0
@export var after_time : float = 1.2

@export_group("連携")
## 呼ぶ仲間のシーン(ルートが Enemy)。空なら呼ばない
@export var wing_scene : PackedScene
## この段階(0 = 第一形態)から呼ぶ
@export var wing_from_phase : int = 2
## 呼ぶ場所(ボスが着いた場所からのずれ。px)。仲間は、ここより画面の上の外から入ってくる
@export var wing_offsets : Array[Vector2] = [Vector2(-150, -40), Vector2(150, -40)]

var _wings : Array[Node] = []

func _init() -> void:
	hold_position = true # 出ていって撃つあいだは、FighterMover に動かさせない

func _run(token : int) -> void:
	await wait_bullets_clear(token)
	if not running(token) or patterns.is_empty() or not is_instance_valid(shooter):
		finish(token)
		return
	# 出ていく
	var view := CameraView.visible_rect(boss)
	var target := view.position + view.size * target_ratio
	var start := boss.global_position
	var tween := boss.create_tween()
	tween.tween_method(func(p : Vector2) -> void:
		if alive():
			boss.global_position = p, start, target, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not running(token):
		return
	if wing_scene and phase() >= wing_from_phase:
		_call_wings(target)
	await wait(settle_time)
	if not running(token):
		_dismiss_wings()
		return
	var pattern := patterns[clampi(phase(), 0, patterns.size() - 1)]
	if pattern:
		shooter.set_patterns([pattern])
	await wait(fire_time)
	if is_instance_valid(shooter):
		shooter.stop()
	_dismiss_wings()
	await wait(after_time)
	finish(token)

func Exit() -> void:
	super.Exit()
	if is_instance_valid(shooter):
		shooter.stop()
	_dismiss_wings()

## 仲間を呼ぶ。画面の上の外から、決めた場所まで降りてくる
func _call_wings(at : Vector2) -> void:
	var parent := boss.get_parent()
	for offset in wing_offsets:
		var wing := wing_scene.instantiate() as Node2D
		if wing == null:
			continue
		var spot := at + offset
		wing.global_position = Vector2(spot.x, CameraView.visible_rect(boss).position.y - 60.0)
		parent.add_child(wing)
		_wings.append(wing)
		var enter := wing.create_tween()
		enter.tween_property(wing, "global_position", spot, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 仲間を帰す(画面の上の外へ抜けて消える)
func _dismiss_wings() -> void:
	for wing in _wings:
		if not is_instance_valid(wing) or (wing is Enemy and wing._is_dead):
			continue
		for node in wing.find_children("*", "", true, false):
			if node is EnemyShooter:
				node.stop()
				node.enabled = false
		var leave := wing.create_tween()
		leave.tween_property(wing, "global_position:y", CameraView.visible_rect(boss).position.y - 120.0, 0.9)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		leave.tween_callback(wing.queue_free)
	_wings.clear()
