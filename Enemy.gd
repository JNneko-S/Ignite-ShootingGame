extends CharacterBody2D
class_name Enemy

signal died(enemy : Enemy)

@export var pattern : MovePattern
@export var mirror_x : bool = false

@onready var hp_component : HPComponent = $HPComponent
@onready var hurtbox : Hurtbox = $Hurtbox

var _tween : Tween
var _is_dead : bool = false

func _ready() -> void:
	hp_component.is_dead.connect(_die)
	hurtbox.recieved_damage.connect(_on_hurtbox_damage)
	# Hurtbox の area_entered がエディタで未接続なら、ここで接続する
	if not hurtbox.area_entered.is_connected(hurtbox._on_area_entered):
		hurtbox.area_entered.connect(hurtbox._on_area_entered)
	if pattern:
		_run_pattern()

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

	if step.wait_after > 0.0 and not _is_dead:
		await get_tree().create_timer(step.wait_after).timeout

func _convert_absolute(pos : Vector2) -> Vector2:
	if mirror_x:
		pos.x = get_viewport_rect().size.x - pos.x
	return pos

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
