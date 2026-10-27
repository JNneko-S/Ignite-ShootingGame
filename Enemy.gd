extends CharacterBody2D
class_name Enemy
## MovePattern に沿って動く敵。HPComponent と Hurtbox で被ダメージ・死亡を処理する。
##
## 必要な子ノード: HPComponent / Hurtbox (Hurtbox直下に CollisionShape2D と CoolDown という名前のTimer)

signal died(enemy : Enemy)

@export var pattern : MovePattern
## true にすると、パターンを左右反転して動く(同じパターンを逆側から出せる)
@export var mirror_x : bool = false
## 移動パターン全体(出現位置と、絶対座標の目標)を、この分だけずらす。
## スポナーが、同じパターンで隊列を組むときに使う
@export var path_offset : Vector2 = Vector2.ZERO
## true なら、mirror_x のとき、見た目と子ノードの位置も左右反転する(砲口が左右逆になる)
@export var mirror_visuals : bool = true

@onready var hp_component : HPComponent = $HPComponent
@onready var hurtbox : Hurtbox = $Hurtbox

var _tween : Tween
var _is_dead : bool = false
## 今の進む向き(CHASE の区間で使う)
var _heading : Vector2 = Vector2.DOWN
var _chase_step : MoveStep
var _chase_elapsed : float = 0.0

signal _chase_finished

func _ready() -> void:
	add_to_group("enemy") # 反射弾の追尾先
	hp_component.is_dead.connect(_die)
	hurtbox.recieved_damage.connect(_on_hurtbox_damage)
	# Hurtbox の area_entered がエディタで未接続なら、ここで接続する
	if not hurtbox.area_entered.is_connected(hurtbox._on_area_entered):
		hurtbox.area_entered.connect(hurtbox._on_area_entered)
	if mirror_x and mirror_visuals:
		_mirror_children()
	if pattern:
		_run_pattern()

## 子ノードの位置を左右反転して、Sprite2D は反転表示にする
func _mirror_children() -> void:
	for child in get_children():
		if child is Node2D:
			child.position.x = -child.position.x
		if child is Sprite2D:
			child.flip_h = not child.flip_h

func _run_pattern() -> void:
	if pattern.override_start_position:
		global_position = _convert_absolute(pattern.start_position)
	for step in pattern.steps:
		await _run_step(step)
		if _is_dead:
			return
	# 全ステップが終わったら(画面外に出ている想定)消す
	queue_free()

func _run_step(step : MoveStep) -> void:
	if step.mode == MoveStep.Mode.CHASE:
		await _run_chase(step)
		return
	var start := global_position
	var target : Vector2
	if step.relative:
		target = global_position + _convert_relative(step.target)
	else:
		target = _convert_absolute(step.target)

	# XとYを同時に、別々のイージングで動かす → カーブになる
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "global_position:x", target.x, step.duration)\
		.set_trans(step.x_trans).set_ease(step.x_ease)
	_tween.tween_property(self, "global_position:y", target.y, step.duration)\
		.set_trans(step.y_trans).set_ease(step.y_ease)
	await _tween.finished
	if target != start:
		_heading = (target - start).normalized()
	await _wait_after(step)

## CHASE: 毎フレーム、自機の方へ少しずつ曲がりながら進む(StagePreview と同じ計算)。
## 動かすのは _physics_process。終わったら _chase_finished が出る(自分のシグナルなので、倒されても安全)
func _run_chase(step : MoveStep) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if step.chase_face_player and player:
		_heading = global_position.direction_to(player.global_position)
	_chase_step = step
	_chase_elapsed = 0.0
	await _chase_finished
	await _wait_after(step)

func _physics_process(delta : float) -> void:
	if _chase_step == null or _is_dead:
		return
	var step := _chase_step
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and step.chase_turn_rate > 0.0:
		var max_turn := deg_to_rad(step.chase_turn_rate) * delta
		var wanted := _heading.angle_to(global_position.direction_to(player.global_position))
		_heading = _heading.rotated(clampf(wanted, -max_turn, max_turn))
	global_position += _heading * step.chase_speed * delta
	_chase_elapsed += delta
	if _chase_elapsed >= step.duration - 0.0001:
		_chase_step = null
		_chase_finished.emit()

func _wait_after(step : MoveStep) -> void:
	if step.wait_after > 0.0 and not _is_dead:
		_tween = create_tween()
		_tween.tween_interval(step.wait_after)
		await _tween.finished

func _convert_absolute(pos : Vector2) -> Vector2:
	if mirror_x:
		var area := CameraView.visible_rect(self) # Camera2D に映っている範囲の、左右の中心で反転する
		pos.x = area.position.x * 2.0 + area.size.x - pos.x
	return pos + path_offset

func _convert_relative(offset : Vector2) -> Vector2:
	if mirror_x:
		offset.x = -offset.x
	return offset

func _on_hurtbox_damage(damage : float, _knockback_dir : Vector2 = Vector2.ZERO) -> void:
	hp_component.apply_damage(ceili(damage))

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	if _tween:
		_tween.kill()
	died.emit(self)
	queue_free()
