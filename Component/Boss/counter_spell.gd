extends Node
class_name CounterSpell
## カウンター大技。ボス(Enemy)の子に置く。
## 決まったきっかけで始まり、Duration 秒のあいだ、ボスはいつもの攻撃をやめて「大技」を撃つ:
##   ・残留弾をばらまく(自分からグレイズしにいって、イグナイトのゲージをためる)
##   ・避けられるくらいの軽い攻撃
##   ・カウンター弾(ShotPattern の Counter Hp Ratio)。イグナイトで返して当てると、ボスを大きく削れる
## 大技のあいだは、次の形態へ移らず、ボスが受けるふつうのダメージは 1 に固定される(カウンター弾だけが効く)。
## きっかけ:
##   Trigger Hp Ratio … HPの割合がこれ以下になったら(1回だけ)
##   Trigger Phase    … ボスの段階(0 から)がこれになったら(1回だけ)
##   Lethal           … 倒れる直前(HP が 0 になるところ)で止まって始め、大技が終わったら倒れる

signal started
signal finished

## 大技の名前(始まるときに出す)
@export var spell_name : String = "COUNTER"
@export_range(-1.0, 1.0, 0.01) var trigger_hp_ratio : float = -1.0
@export var trigger_phase : int = -1
@export var lethal : bool = false
## 大技の長さ(秒)と、名前が出てから撃ち始めるまでの時間(秒)
@export var duration : float = 14.0
@export var start_delay : float = 1.4
## 大技で撃つ弾幕(同時に撃つ)
@export var patterns : Array[ShotPattern] = []
## 撃つ位置の目安にする砲口。空なら、ボスの EnemyShooterComponent の位置。
## 大技は、この位置に置いた大技専用の砲口から撃つ(ボスのステートが、いつもの砲口を動かしても、大技は邪魔されない)
@export var shooter : EnemyShooter
## 大技のあいだ止めておくもの(ボスを動かすステートや、移動の部品など)
@export var freeze_nodes : Array[Node] = []
## 大技のあいだにイグナイトで焼いた弾1発あたり、最後に落ちるスコアアイテムの点(0 なら落とさない)と、アイテムの数の上限
@export var burn_reward_points : int = 400
@export var burn_reward_max_items : int = 60

const _SHOOTER_SCENE := preload("res://Component/Shooter/enemy_shooter_component.tscn")

var _enemy : Enemy
var _hp : HPComponent
## 大技専用の砲口(大技のあいだだけ、ボスの子に置く)
var _spell_shooter : EnemyShooter
var _done : bool = false
var _active : bool = false
var _burned_at_start : int = 0

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_hp = _enemy.get_node_or_null("HPComponent") as HPComponent # ボスより先に準備されるので、直接探す
	if _hp == null:
		return
	if shooter == null:
		shooter = _enemy.get_node_or_null("EnemyShooterComponent") as EnemyShooter
	if lethal:
		_hp.hp_floor = 1 # 倒れる直前で止める
		_hp.floor_reached.connect(_start)
	if trigger_hp_ratio > 0.0:
		_hp.hp_changed.connect(_on_hp_changed)
	if trigger_phase >= 0:
		var controller := _controller()
		if controller:
			controller.phase_started.connect(func(index : int) -> void:
				if index == trigger_phase:
					_start())

func is_active() -> bool:
	return _active

func _on_hp_changed() -> void:
	if _done or _active or _hp.max_hp <= 0 or _hp.hp <= 0:
		return
	if _hp.hp_floor > 0 and _hp.hp <= _hp.hp_floor:
		return # 倒れる直前で止まった: そこで始まる大技(Lethal)を先にする
	if float(_hp.hp) / _hp.max_hp <= trigger_hp_ratio:
		_start()

func _controller() -> BossPhaseController:
	for child in _enemy.get_children():
		if child is BossPhaseController:
			return child
	return null

func _start() -> void:
	if _done or _active or not is_inside_tree():
		return
	# ほかのカウンター大技が動いていたら、重ねない
	if _enemy.get_meta(&"counter_spell", false):
		return
	_active = true
	_enemy.set_meta(&"counter_spell", true)
	_hp.damage_lock = true
	started.emit()
	var tree := get_tree()
	EnemyBullet.vanish_all(tree, _enemy.global_position)
	_announce()
	# いつもの攻撃と動きを止める
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			(node as EnemyShooter).suppressed = true
			(node as EnemyShooter).stop()
		elif node is BeamShooter:
			(node as BeamShooter).set_silenced(true)
	for node in freeze_nodes:
		if is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	await tree.create_timer(start_delay, false).timeout
	if not _still_alive():
		return
	# 大技専用の砲口から撃つ(いつもの砲口は黙ったまま。ボスのステートがいつもの砲口に命令しても、大技は止まらない)
	_spell_shooter = _SHOOTER_SCENE.instantiate() as EnemyShooter
	_spell_shooter.autostart = false
	_spell_shooter.name = "CounterSpellShooter"
	_enemy.add_child(_spell_shooter)
	_spell_shooter.global_position = shooter.global_position if is_instance_valid(shooter) else _enemy.global_position
	_spell_shooter.set_patterns(patterns, [], false, true) # どの難易度でも、残留弾・軽い攻撃・カウンター弾をそろえて撃つ
	_burned_at_start = EnemyBullet.burned_total
	await tree.create_timer(duration, false).timeout
	if not _still_alive():
		return
	_finish()

## 大技のあいだにイグナイトで焼いた弾の数だけ、最後にボスからスコアアイテムが落ちる(たくさん焼くほど、たくさん落ちる)
func _drop_burn_reward() -> void:
	var burned := maxi(EnemyBullet.burned_total - _burned_at_start, 0)
	if burned <= 0 or burn_reward_points <= 0:
		return
	var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score_system == null:
		return
	var count := clampi(ceili(burned / 3.0), 4, burn_reward_max_items)
	score_system.spawn_items(_enemy.global_position, burned * burn_reward_points, count, 2.4)

func _still_alive() -> bool:
	return is_inside_tree() and is_instance_valid(_enemy) and not _enemy._is_dead

func _finish() -> void:
	_active = false
	_done = true
	if is_instance_valid(_spell_shooter):
		_spell_shooter.stop()
		_spell_shooter.queue_free()
		_spell_shooter = null
	for node in freeze_nodes:
		if is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_INHERIT
	_hp.damage_lock = false
	_enemy.remove_meta(&"counter_spell")
	finished.emit()
	_drop_burn_reward()
	if lethal:
		# 大技を撃ちきって、力尽きる
		_hp.hp_floor = 0
		_hp.apply_damage(_hp.hp + 1)
		return
	var controller := _controller()
	if controller:
		controller.resume_after_counter_spell()
	else:
		for node in _enemy.find_children("*", "", true, false):
			if node is EnemyShooter:
				(node as EnemyShooter).suppressed = false
				if (node as EnemyShooter).has_phases():
					(node as EnemyShooter).set_phase(0, true)
			elif node is BeamShooter:
				(node as BeamShooter).set_silenced(false)

## 大技の名前を、ボスの下に大きく出す
func _announce() -> void:
	var tree := get_tree()
	ScreenFlash.play(tree, 0.3)
	var at := _enemy.global_position + Vector2(0, 70)
	FloatingText.spawn(tree, at, "COUNTER CHANCE", Color(1.0, 0.6, 0.2), 16)
	FloatingText.spawn(tree, at + Vector2(0, 20), spell_name, Color(1.0, 0.95, 0.85), 13)
