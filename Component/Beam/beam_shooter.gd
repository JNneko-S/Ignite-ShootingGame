extends Node2D
class_name BeamShooter
## 回るビーム。敵(ボスなど)の子に置く。予告の細い線 → 太いビームになって、回りながら薙ぎ払う → 消える、をくり返す。
##   ・ビームは敵弾と同じ当たり判定(Hitbox、敵の弾のレイヤー)。自機が触れると被弾する。グレイズもできる
##   ・Clockwise がオンなら時計回り(画面で右回り)、オフなら反時計回り
##   ・ボスの段階(BossPhaseController)が Active From Phase 以上のときだけ撃つ
##   ・持ち主の部位(EnemyPart)が壊れたら、もう撃たない
##   ・列車(TrainBossMover)が撃つのを止めているあいだは撃たない(Fire While Moving がオフで、動いているとき)
## 見た目は _draw で描く(芯の白と、外側の色の光)。

## 撃ち始める向き(度。0 で右、90 で下)
@export var start_angle_deg : float = 90.0
## 1回で回る角度(度)
@export var sweep_deg : float = 180.0
## オンなら時計回り
@export var clockwise : bool = true
## 長さ(px)と太さ(px)
@export var length : float = 900.0
@export var width : float = 22.0
## 予告の時間・撃つ時間・休む時間(秒)
@export var warn_time : float = 1.0
@export var fire_time : float = 3.0
@export var rest_time : float = 2.5
## 最初に撃つまでの時間(秒)
@export var start_delay : float = 2.0
## ボスのこの段階(0 から)以上のときだけ撃つ。-1 なら段階に関係なく撃つ
@export var active_from_phase : int = -1
## 光の色
@export var color : Color = Color(1.0, 0.35, 0.2)
## オフにすると、撃たない(ステートなどから start_beam() を呼ぶとき)
@export var autostart : bool = true
## このビームを撃つ部位(砲台)。ビームはこの砲台の位置から出て、壊れたら撃たない(空なら、親をたどって EnemyPart を探す)
@export var part : EnemyPart

enum BeamState { IDLE, WARN, FIRE }
var state : BeamState = BeamState.IDLE

var _hitbox : Hitbox
var _shape : CollisionShape2D
var _angle : float = 0.0
var _time : float = 0.0
var _serial : int = 0

func _ready() -> void:
	_build_hitbox()
	_set_hit(false)
	if autostart:
		_loop()

func _build_hitbox() -> void:
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 32 # 敵の弾と同じ
	_hitbox.collision_mask = 0
	_hitbox.damage = 1
	_hitbox.damage_source_type = Hitbox.DamageSourceType.Enemy
	_shape = CollisionShape2D.new()
	_shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, width * 0.6) # 見た目より少し細く
	_shape.shape = rect
	_shape.position = Vector2(length * 0.5, 0.0)
	_hitbox.add_child(_shape)
	add_child(_hitbox)

func _set_hit(on : bool) -> void:
	if _shape:
		_shape.set_deferred("disabled", not on)

## くり返し撃つ
func _loop() -> void:
	_serial += 1
	var serial := _serial
	await _wait(start_delay)
	while serial == _serial and is_inside_tree():
		if _can_fire():
			await _fire_once(serial)
		else:
			await _wait(0.5)
			continue
		await _wait(rest_time)

## 1回だけ撃つ(ステートなどから呼ぶ)
func start_beam() -> void:
	_serial += 1
	await _fire_once(_serial)

## 撃つのをやめる
func stop_beam() -> void:
	_serial += 1
	state = BeamState.IDLE
	_set_hit(false)
	queue_redraw()

func _fire_once(serial : int) -> void:
	_angle = deg_to_rad(start_angle_deg)
	rotation = 0.0
	state = BeamState.WARN
	_time = 0.0
	await _wait(warn_time)
	if serial != _serial:
		return
	state = BeamState.FIRE
	_time = 0.0
	_set_hit(true)
	await _wait(fire_time)
	if serial != _serial:
		return
	state = BeamState.IDLE
	_set_hit(false)
	queue_redraw()

func _can_fire() -> bool:
	if _part_destroyed():
		return false
	var enemy := _owner_enemy()
	if enemy and enemy.hp_component.hp <= 0:
		return false
	if TrainBossMover.holds_fire(enemy) or EnemyShooter.is_holding_fire():
		return false # 列車が撃つのを止めているとき・敵がみんな撃つのを止めているとき(演出のあいだ)は撃たない
	if not _in_view_height():
		return false # 画面の上下の外からは撃たない(左右の外からは撃つ)
	if TrainBossMover.is_behind_player(enemy, global_position):
		return false # 列車が動いていて、自機より後ろ(下)にあるときは、撃ち始めない
	if active_from_phase < 0 or enemy == null:
		return true
	for child in enemy.get_children():
		if child is BossPhaseController:
			return child.current_phase() >= active_from_phase
	return true

func _process(delta : float) -> void:
	# 撃つ位置は、砲台(Part)の位置に合わせる(列車が動いても、砲台から出る)
	if part and is_instance_valid(part):
		global_position = part.global_position
	if state == BeamState.IDLE:
		return
	_time += delta
	if _part_destroyed() or (_owner_enemy() and _owner_enemy().hp_component.hp <= 0) or TrainBossMover.holds_fire(_owner_enemy()) or EnemyShooter.is_holding_fire() or not _in_view_height():
		stop_beam() # 予告の途中でも、撃っている途中でも止める
		if autostart:
			_loop()
		return
	if state == BeamState.FIRE:
		var speed := deg_to_rad(sweep_deg) / maxf(fire_time, 0.01)
		_angle += speed * delta * (1.0 if clockwise else -1.0) # 画面は y が下なので、角度が増えると時計回り
	_hitbox.global_rotation = _angle
	queue_redraw()

func _draw() -> void:
	if state == BeamState.IDLE:
		return
	var dir := Vector2.from_angle(_angle - global_rotation)
	var end := dir * length
	if state == BeamState.WARN:
		# 予告: 細い線が点滅する
		var blink := 0.35 + 0.35 * absf(sin(_time * 18.0))
		draw_line(Vector2.ZERO, end, Color(color, blink), 2.0)
		return
	# ビーム: 外側の光 → 内側の光 → 白い芯。少しゆらぐ
	var wobble := 1.0 + 0.12 * sin(_time * 40.0)
	var grow := clampf(_time / 0.12, 0.0, 1.0)
	var w := width * wobble * grow
	draw_line(Vector2.ZERO, end, Color(color, 0.25), w * 1.8)
	draw_line(Vector2.ZERO, end, Color(color, 0.7), w)
	draw_line(Vector2.ZERO, end, Color(1.0, 0.95, 0.85), w * 0.4)
	draw_circle(Vector2.ZERO, w * 0.9, Color(1.0, 0.9, 0.8, 0.9))

## 撃つ位置の高さが、画面の中か(画面の上下の外にいるときは撃たない)
func _in_view_height() -> bool:
	var view := CameraView.visible_rect(self)
	return global_position.y >= view.position.y and global_position.y <= view.end.y

func _part_destroyed() -> bool:
	if part:
		return part.is_destroyed()
	var node := get_parent()
	while node and not node is Enemy:
		if node is EnemyPart:
			return node.is_destroyed()
		node = node.get_parent()
	return false

func _owner_enemy() -> Enemy:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node
		node = node.get_parent()
	return null

func _wait(seconds : float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, false).timeout
