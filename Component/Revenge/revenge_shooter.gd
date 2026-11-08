extends Node2D
class_name RevengeShooter
## 撃ち返し弾。ボス・中ボス・部位(EnemyPart)の子に置くと、決まったきっかけで Pattern の弾を撃つ。
## このノードの位置から撃つ(好きな位置に置く。部位の砲台の真ん中など)。
##
## きっかけ(いくつでもオンにできる):
##   ・壊されたとき : 親に部位(EnemyPart)があれば、その部位が壊れたとき。なければ、敵が倒されたとき
##   ・ダメージ     : Damage Step のダメージを受けるたびに(撃ち込むほど撃ち返してくる)
##   ・段階の切り替え: ボスの BossPhase が次の段階になったとき(弾消しのあとに撃つ)
##
## Pattern は、Shot Count 回(Interval おき)を1回分として撃つ。Start Delay・Loop・Pause は使わない。
## 渦巻き(Rotate Per Shot)などは、撃ち返すたびに続きから回る。
## 敵が倒されたあとも、撃ち終わるまでは残る(Delay を長くすると、大爆発のあとに撃てる)。

@export var pattern : ShotPattern
## Pattern に弾シーンがないときの弾
@export var default_bullet_scene : PackedScene = preload("res://GameScene/Bullet/E_Purple_Revenge.tscn")

@export_group("きっかけ")
## 部位が壊れたとき(部位の子でなければ、敵が倒されたとき)に撃つ
@export var on_destroyed : bool = true
## このダメージを受けるたびに撃つ。0 なら、ダメージでは撃たない
@export var damage_step : int = 0
## ボスの段階が切り替わったときに撃つ
@export var on_phase_change : bool = false

@export_group("撃ち方")
## きっかけから撃つまでの待ち(秒)。ボスが倒されたときは、大爆発(Death Explosion の Duration)より長くすると、
## 爆発の弾消しに消されずに、最後に撃ってくる
@export var delay : float = 0.0
## ダメージで撃つとき、次に撃てるまでの最短の間隔(秒)。連射で撃ち返しが重なりすぎないように
@export var cooldown : float = 0.5
## 自機がこの距離(px)より近いときは撃たない(避けようのない撃ち返しを防ぐ)。0 なら距離に関係なく撃つ
@export var safe_distance : float = 0.0

var _part : EnemyPart
var _body : Enemy
var _last_hp : int = 0
var _damage_stock : int = 0
var _ready_at_msec : int = 0
var _shot_index : int = 0
var _detached : bool = false

func _ready() -> void:
	_find_owner_nodes()
	if _part:
		_part.destroyed.connect(func(_p : EnemyPart) -> void: _trigger(on_destroyed))
	elif _body:
		_body.died.connect(func(_e : Enemy) -> void: _trigger(on_destroyed))
	_last_hp = _current_hp()
	# BossPhaseController は、StageRunner があとから付けるので、1フレーム待ってから探す
	_connect_phase.call_deferred()

func _find_owner_nodes() -> void:
	var node := get_parent()
	while node:
		if node is EnemyPart and _part == null:
			_part = node
		if node is Enemy:
			_body = node
			return
		node = node.get_parent()

func _connect_phase() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	for child in _body.get_children():
		if child is BossPhaseController:
			child.phase_started.connect(func(_index : int) -> void: _trigger(on_phase_change))
			return

## 部位の HP(部位の子でなければ、敵の HP)
func _current_hp() -> int:
	if _part:
		return _part.hp
	if _body and _body.hp_component:
		return _body.hp_component.hp
	return 0

func _physics_process(_delta : float) -> void:
	if _detached or damage_step <= 0:
		return
	var hp := _current_hp()
	if hp < _last_hp:
		_damage_stock += _last_hp - hp
	_last_hp = hp
	if hp <= 0 or (_part and _part.is_destroyed()):
		return
	if _damage_stock >= damage_step and Time.get_ticks_msec() >= _ready_at_msec:
		_damage_stock %= damage_step # 一気に削られても、1回分だけ撃つ
		_ready_at_msec = Time.get_ticks_msec() + int(cooldown * 1000.0)
		_trigger(true)

func _trigger(enabled : bool) -> void:
	if not enabled or pattern == null:
		return
	var dying := _body == null or not is_instance_valid(_body) or _body.hp_component.hp <= 0
	if dying and not _detached:
		_detach()
	_fire_volley()

## 敵が倒されて消えても撃ち終われるように、ステージ直下へ移る(位置はそのまま)
func _detach() -> void:
	_detached = true
	reparent(get_tree().current_scene) # 位置はそのまま

func _fire_volley() -> void:
	await _wait(delay)
	for i in maxi(pattern.shot_count, 1):
		_fire_once()
		if i < pattern.shot_count - 1:
			await _wait(pattern.interval)
	if _detached:
		queue_free()

func _fire_once() -> void:
	if EnemyShooter.is_holding_fire():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and safe_distance > 0.0 and player.global_position.distance_to(global_position) < safe_distance:
		_shot_index += 1
		return
	if not CameraView.visible_rect(self).has_point(global_position):
		_shot_index += 1
		return
	var aim := (player.global_position - global_position).angle() if player else Vector2.DOWN.angle()
	var mirror := _body.mirror_x if _body and is_instance_valid(_body) else false
	EnemyShooter.spawn_bullets(pattern, _shot_index, aim, global_position, get_tree().current_scene,
			default_bullet_scene, mirror)
	_shot_index += 1

## このノードに紐づく Tween で待つ(ノードが消えたら、処理も止まる)
func _wait(seconds : float) -> void:
	if seconds <= 0.0:
		return
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished
