extends Node
class_name BackgroundEmerge
## 敵が「背景から出てくる」部品(ステージ3)。StageRunner が、SpawnEvent の Emerge に合わせて、敵に付ける。
## 出てくるまでは、背景の姿(小さく・暗く・薄く、当たらない・撃たない)で動き、出てきたら いつもの敵になる。
##   APPROACH … 敵が最初に向かう地点に、小さく暗い姿で現れ、だんだん大きく濃くなって、こちらへ飛んできたように前に出る。
##              前に出たら、移動パターンの続き(2つ目のステップから)を動く
##   RISE     … 画面の下のほうの背景から、上へ飛び去る(遠ざかって小さくなる)。
##              そのあと、いつもの移動パターンで、画面の上から入り直してくる
##   SCRAMBLE … 格納庫(背景の床)から緊急発進する(ステージ4)。床の上で機首を上へ向けて点火し、
##              アフターバーナーを噴いて一気に飛び立ち(上がりながら大きく・明るくなる)、
##              最初に向かう地点を少し行き過ぎてから、くるっと反転して襲ってくる。そのあと移動パターンの続きを動く

enum Mode { NONE, APPROACH, RISE, SCRAMBLE }

var mode : Mode = Mode.APPROACH
## 出てくるまでの時間(秒)
var time : float = 1.2
## 背景の姿の色(夕暮れの空に溶けた、暗く薄い色)
var ghost_color : Color = Color(0.3, 0.22, 0.36, 0.5)
## 背景の姿の大きさ(元の何倍)
var ghost_scale : float = 0.3

var _enemy : Enemy
var _pattern : MovePattern
var _scale : Vector2
var _modulate : Color
var _z : int
var _z_relative : bool
var _rotation : float

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null or mode == Mode.NONE:
		return
	# 移動パターンは、出てくるまで預かる(親の _ready より先に呼ばれるので、まだ動き出していない)
	_pattern = _enemy.pattern
	_enemy.pattern = null
	_begin.call_deferred()

func _begin() -> void:
	if not is_instance_valid(_enemy):
		return
	_scale = _enemy.scale
	_modulate = _enemy.modulate
	_z = _enemy.z_index
	_z_relative = _enemy.z_as_relative
	_rotation = _enemy.rotation
	_set_active(false)
	_enemy.z_as_relative = false
	_enemy.z_index = -16 # 空と雲の背景より手前、ふつうの敵や弾より奥
	_enemy.modulate = ghost_color
	_enemy.scale = _scale * ghost_scale
	if mode == Mode.APPROACH:
		await _approach()
	elif mode == Mode.SCRAMBLE:
		await _scramble()
	else:
		await _rise()

## こちらへ飛んできたように、前に出る
func _approach() -> void:
	var target := _first_target()
	_enemy.global_position = target + Vector2(0.0, -30.0) # 遠いところ(少し上)から
	var tween := _enemy.create_tween().set_parallel(true)
	tween.tween_property(_enemy, "scale", _scale, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_enemy, "modulate", _modulate, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_enemy, "global_position", target, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_instance_valid(_enemy):
		return
	_restore()
	# 移動パターンの続き(2つ目のステップから)を、今の位置から動く
	if _pattern and _pattern.steps.size() > 1:
		var rest := MovePattern.new()
		rest.override_start_position = false
		rest.steps.assign(_pattern.steps.slice(1))
		_enemy.pattern = rest
		_enemy._run_pattern()
	elif _pattern == null or _pattern.steps.is_empty():
		pass # その場に残る

## 格納庫から緊急発進する。画面の外(下、または左右の端に近い地点なら横)の床から、
## アフターバーナーを噴いて一気に飛び込んでくる。床に近い(低い)うちは暗く、上がるほど明るく大きくなる。
## 最初に向かう地点を少し行き過ぎてから、くるっと反転して襲ってくる
func _scramble() -> void:
	var target := _first_target()
	var view := CameraView.visible_rect(_enemy)
	var center_x := view.get_center().x
	var side := target.x - center_x
	var pad : Vector2
	if absf(side) > view.size.x * 0.28:
		# 端に近い地点へ向かうときは、その側の画面の外から、斜めに飛び込む
		pad = Vector2(view.position.x - 50.0 if side < 0.0 else view.end.x + 50.0, target.y + view.size.y * 0.4)
	else:
		pad = Vector2(target.x, view.end.y + 50.0) # 画面の下の外から
	_enemy.global_position = pad
	_enemy.z_index = 0 # 床(背景)より手前、ふつうの敵や弾より奥
	var low_color := Color(0.22, 0.22, 0.3, 1.0) # 床に近い、影になった姿
	_enemy.modulate = low_color
	_enemy.scale = _scale * 0.6
	var dir := (target - pad).normalized()
	_enemy.rotation = dir.angle() - PI / 2.0 # 機首(ふだんは下向き)を、飛んでいく向きへ
	var flame := EmergeFlame.new()
	flame.root_offset = _tail_offset()
	flame.amount = 0.8
	_enemy.add_child(flame)
	var launch := time * 0.8
	var turn := maxf(time * 0.2, 0.18)
	var overshoot := dir * 34.0
	var tween := _enemy.create_tween()
	# 発進: 一気に飛び込む(はじめから速く、行き過ぎるところでゆるむ)。上がりながら大きく、明るくなる
	tween.tween_property(_enemy, "global_position", target + overshoot, launch).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_enemy, "scale", _scale * 1.08, launch).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_enemy, "modulate", _modulate, launch).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(flame, "amount", 1.0, launch * 0.3)
	# 反転: くるっとこちらへ向き直る(画面の左右どちら側かで、回る向きを変える)
	var from := _enemy.rotation
	var diff := wrapf(_rotation - from, -PI, PI)
	if absf(diff) > PI * 0.9:
		diff = absf(diff) * (1.0 if side < 0.0 else -1.0) # 真後ろへ向き直るときは、画面の外側へ回る
	var to := from + diff
	tween.tween_property(_enemy, "rotation", to, turn).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_enemy, "global_position", target, turn).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_enemy, "scale", _scale, turn)
	tween.parallel().tween_property(flame, "amount", 0.3, turn)
	await tween.finished
	if not is_instance_valid(_enemy):
		return
	_restore()
	# 炎は少し残してから消す(反転のあとも、勢いが残っているように)
	var fade := flame.create_tween()
	fade.tween_property(flame, "amount", 0.0, 0.5)
	fade.tween_callback(flame.queue_free)
	if _pattern and _pattern.steps.size() > 1:
		var rest := MovePattern.new()
		rest.override_start_position = false
		rest.steps.assign(_pattern.steps.slice(1))
		_enemy.pattern = rest
		_enemy._run_pattern()

## 機体の後ろの端(機首の反対)までの距離。絵の大きさから求める
func _tail_offset() -> float:
	for node in _enemy.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture and sprite.visible:
			return absf(sprite.get_rect().position.y * sprite.scale.y) * 0.8
	return 12.0

## 背景の下のほうから上へ飛び去ってから、いつもの動きで上から入り直す
func _rise() -> void:
	var view := CameraView.visible_rect(_enemy)
	var x := _first_target().x
	_enemy.global_position = Vector2(x, view.end.y - view.size.y * 0.15)
	_enemy.rotation = _rotation + PI # 上へ飛び去るあいだは、機首を上へ向ける(後ろ向きに飛ばないように)
	var tween := _enemy.create_tween().set_parallel(true)
	tween.tween_property(_enemy, "global_position:y", view.position.y - 40.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_enemy, "scale", _scale * ghost_scale * 0.6, time) # 遠ざかって小さくなる
	await tween.finished
	if not is_instance_valid(_enemy):
		return
	_restore()
	if _pattern:
		_enemy.pattern = _pattern
		_enemy._run_pattern() # 画面の上から入り直す

## 移動パターンで、最初に向かう地点(わからなければ、出てくる位置の少し下)
func _first_target() -> Vector2:
	if _pattern == null:
		return _enemy.global_position
	var start := _enemy._convert_absolute(_pattern.start_position) if _pattern.override_start_position else _enemy.global_position
	for step in _pattern.steps:
		if step.mode == MoveStep.Mode.CHASE:
			break
		if step.relative:
			return start + _enemy._convert_relative(step.target)
		return _enemy._convert_absolute(step.target)
	var view := CameraView.visible_rect(_enemy)
	return Vector2(start.x, view.position.y + view.size.y * 0.25)

## いつもの敵に戻す(見た目・当たり判定・撃つ)
func _restore() -> void:
	_enemy.scale = _scale
	_enemy.rotation = _rotation
	_enemy.modulate = _modulate
	_enemy.z_index = _z
	_enemy.z_as_relative = _z_relative
	_set_active(true)

## 当たり判定と撃つのを、止める・戻す。背景の姿のあいだは、ロックオンや全滅待ちの数にも入れない
func _set_active(on : bool) -> void:
	var hurtbox := _enemy.get_node_or_null("Hurtbox")
	if hurtbox:
		for shape in hurtbox.find_children("*", "CollisionShape2D", false, false):
			shape.set_deferred("disabled", not on)
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			node.enabled = on
	if on:
		_enemy.add_to_group("enemy")
	else:
		_enemy.remove_from_group("enemy")
