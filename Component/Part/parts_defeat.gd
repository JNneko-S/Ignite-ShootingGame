extends Node
class_name PartsDefeat
## 部位(砲台など)を撃って倒す敵にする部品。敵(Enemy)の子に置く(列車のボスなど)。
##   ・本体そのものの当たり判定(Enemy の Hurtbox)は切る。撃てるのは部位だけ
##   ・本体の HP(ボスのゲージ)は、はじめは部位の HP の合計
## 倒れ方は2通り:
##   Revive On Phase がオフ(中ボス): 本体の HP = 壊れていない部位の HP の合計。部位が全部壊れたら倒れる
##   Revive On Phase がオン(ボス):   部位に入ったダメージが、そのまま本体の HP から減る。
##       ボスの段階が変わると、壊れた部位が直る(新しい弾幕で撃ってくる)。本体の HP が 0 になったら倒れる。
##       段階の途中で部位が全部壊れたら、少し待ってから全部直す(HP を削れなくなるのを防ぐ)
## 倒れたとき、まだ壊れていない部位は、順に爆発して壊れる(壊れた姿のまま残る)。
## 部位は、敵の中の EnemyPart を全部使う(Parts に入れれば、それだけ)。

## 数える部位。空なら、敵の中の EnemyPart を全部
@export var parts : Array[EnemyPart] = []
## オンなら、本体の Hurtbox を切る(本体には弾が当たらない)
@export var disable_body_hurtbox : bool = true
## 部位の HP の倍率(同じ列車を、弱い援護として出すときなどに下げる)
@export var part_hp_scale : float = 1.0
## オンなら、ロックオンは部位にだけかかる(本体はロックしない。本体には当たり判定がないので)
@export var lock_parts_only : bool = true
## オンなら、ボスの段階が変わったときに、壊れた部位を直す(上の「倒れ方」を参照)
@export var revive_on_phase : bool = false
## 段階の途中で部位が全部壊れたとき、直すまでの時間(秒)
@export var revive_all_delay : float = 2.0
## 倒れたとき、残っている部位を順に爆発させる間隔(秒)
@export var death_break_interval : float = 0.12
## ボスがこの段階(0 から)に入ったら、部位は直らなくなり、部位を全部壊すと倒れる(ゲージは、残っている部位の量で減る)。
## -1 ならしない
@export var final_phase : int = 2

## 最後の段階: 部位を全部壊したら倒れる
var _final_mode : bool = false
## 最後の段階に入ったときの本体の HP と、部位の HP の合計
var _final_start_hp : int = 0
var _final_total : int = 0

var _enemy : Enemy
var _hp : HPComponent
var _reviving : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("PartsDefeat: 親が Enemy ではありません")
		return
	if parts.is_empty():
		for node in _enemy.find_children("*", "", true, false):
			if node is EnemyPart:
				parts.append(node)
	var total := 0
	if lock_parts_only:
		_enemy.add_to_group("no_lock")
	for part in parts:
		if lock_parts_only:
			part.add_to_group("lock_target")
		# 中ボス: 本体の HP は部位の残りから決める / ボス: 部位に入ったダメージを本体へ
		part.damage_to_body = 1.0 if revive_on_phase else 0.0
		if not is_equal_approx(part_hp_scale, 1.0):
			part.max_hp = maxi(roundi(part.max_hp * part_hp_scale), 1)
			part.hp = part.max_hp
		total += part.max_hp
	# 親の Enemy の _ready はまだなので、@onready の変数ではなく、ノードを直接見る
	_hp = _enemy.get_node_or_null("HPComponent") as HPComponent
	if _hp and total > 0:
		_hp.max_hp = total
		_hp.hp = total
	var body_hurtbox := _enemy.get_node_or_null("Hurtbox")
	if disable_body_hurtbox and body_hurtbox:
		for shape in body_hurtbox.find_children("*", "CollisionShape2D", false, false):
			shape.set_deferred("disabled", true)
	_enemy.died.connect(_on_died)
	if revive_on_phase:
		_connect_phases.call_deferred()

func _connect_phases() -> void:
	var controller := _controller()
	if controller:
		controller.phase_started.connect(func(index : int) -> void:
			if index > 0:
				_revive_all()
			if final_phase >= 0 and index >= final_phase:
				_enter_final_mode())

## 最後の段階に入った: 部位は直らなくなり、本体の HP は「残っている部位の量」で減る。全部壊したら倒れる
func _enter_final_mode() -> void:
	if _final_mode:
		return
	_final_mode = true
	_final_start_hp = _hp.hp
	_final_total = 0
	for part in parts:
		if is_instance_valid(part):
			part.damage_to_body = 0.0 # 本体の HP は、部位の残りから決める
			_final_total += part.max_hp

func _physics_process(_delta : float) -> void:
	if _hp == null or _hp.hp <= 0:
		return
	var left := 0
	for part in parts:
		if is_instance_valid(part) and not part.is_destroyed():
			left += maxi(part.hp, 0)
	if _final_mode:
		var target := ceili(float(_final_start_hp) * left / maxf(_final_total, 1.0))
		if left == 0:
			target = 0 # 全部壊した
		if target < _hp.hp:
			_hp.apply_damage(_hp.hp - target)
		return
	if revive_on_phase:
		# 段階の途中で全部壊れたら、少し待って全部直す
		if left == 0 and not _reviving:
			_reviving = true
			await get_tree().create_timer(revive_all_delay, false).timeout
			if _hp.hp > 0:
				_revive_all()
			_reviving = false
		return
	var hp := _hp.hp
	if left < hp:
		# 全部壊れたときは、残りを全部減らして倒す
		_hp.apply_damage(hp - left if left > 0 else hp)

## 部位を全部直して(壊れていない部位も HP を満タンに)、今の段階の弾幕で撃たせる
func _revive_all() -> void:
	var controller := _controller()
	var phase := controller.current_phase() if controller else 0
	for part in parts:
		if is_instance_valid(part) and not part.is_destroyed():
			part.hp = part.max_hp
	for part in parts:
		if is_instance_valid(part) and part.is_destroyed():
			part.revive()
			for shooter in part.shooters:
				if is_instance_valid(shooter) and shooter.has_phases():
					shooter.set_phase(phase)

## 倒れた: まだ壊れていない部位を、順に爆発させて壊す(壊れた姿のまま残る)
func _on_died(_e : Enemy) -> void:
	var left : Array = parts.filter(func(p) -> bool: return is_instance_valid(p) and not p.is_destroyed())
	left.shuffle()
	for part in left:
		if not is_instance_valid(part):
			continue
		part._destroy()
		await get_tree().create_timer(death_break_interval, false).timeout

func _controller() -> BossPhaseController:
	for child in _enemy.get_children():
		if child is BossPhaseController:
			return child
	return null
