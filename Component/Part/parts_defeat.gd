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
## 0 より大きければ、本体の HP(ボスのゲージ)をこの値にする(部位の HP の合計を使わない)。
## 部位を柔らかくして、たくさん壊しながら戦うボスにするときに使う(Revive On Phase がオンのとき)
@export var body_hp : int = 0
## 0 より大きければ、壊れた部位は、この秒数たつと1つずつ直る(Revive On Phase がオンで、最後の段階より前のとき)
@export var revive_part_delay : float = 0.0
## オンなら、ロックオンは部位にだけかかる(本体はロックしない。本体には当たり判定がないので)
@export var lock_parts_only : bool = true
## オンなら、ボスの段階が変わったときに、壊れた部位を直す(上の「倒れ方」を参照)
@export var revive_on_phase : bool = false
## 段階の途中で部位が全部壊れたとき、直すまでの時間(秒)
@export var revive_all_delay : float = 2.0
## 倒れたとき、残っている部位を順に爆発させる間隔(秒)
@export var death_break_interval : float = 0.12
## ボスがこの段階(0 から)に入ったら、部位は直らなくなり、部位を全部壊すと倒れる(ゲージは、残っている部位の量で減る)。
## 部位が1つでも残っているうちは、ほかのダメージ(援護の爆発など)では倒れない
## -1 ならしない
@export var final_phase : int = 2

## 最後の段階に入ったときに、部位の HP をこの倍にする(最後の段階を長く・固くする)。1 なら変えない
@export var final_part_hp_scale : float = 1.0

@export_group("援護がいるあいだの装甲")
## オンなら、援護(Support Group の敵)が生きているあいだ、部位は装甲で弾をはじく:
## 入るダメージが Armored Damage Scale 倍になり、当たった所に「はじいた」火花が出る。援護を倒すと、装甲がなくなる
@export var support_armor : bool = false
@export_range(0.0, 1.0, 0.05) var armored_damage_scale : float = 0.15
## 援護のグループ(StageRunner が付ける「stage_ + タグ」)
@export var support_group : StringName = &"stage_support"
## はじいたときの音(短く高い音がよい)。空なら鳴らさない
@export var deflect_sound : AudioStream = preload("res://Assets/Sounds/Rockon/AS_119891_コックピットなどの細かい電子音_10.mp3")
@export var deflect_volume_db : float = -16.0

## 最後の段階: 部位を全部壊したら倒れる
var _final_mode : bool = false
## 今、装甲があるか(援護が生きているか)。毎フレーム確かめる
var _armored : bool = false
var _deflect_player : AudioStreamPlayer
## 最後の段階に入ったときの本体の HP と、部位の HP の合計
var _final_start_hp : int = 0
var _final_total : int = 0
## 最後の段階に入ってから、部位以外から受けたダメージ(援護の列車の爆発など)
var _final_extra : int = 0

var _enemy : Enemy
var _hp : HPComponent
var _reviving : bool = false
## 部位が壊れた時刻(ミリ秒)。Revive Part Delay で1つずつ直すのに使う
var _broken_at : Dictionary = {}

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
	if revive_on_phase and body_hp > 0:
		total = body_hp # ゲージは決まった値(部位は柔らかく、何度も直る)
	if _hp and total > 0:
		_hp.max_hp = total
		_hp.hp = total
	for part in parts:
		part.destroyed.connect(func(p : EnemyPart) -> void: _broken_at[p] = Time.get_ticks_msec())
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
	_final_extra = 0
	for part in parts:
		if is_instance_valid(part):
			part.damage_to_body = 0.0 # 本体の HP は、部位の残りから決める
			if not is_equal_approx(final_part_hp_scale, 1.0):
				part.max_hp = maxi(roundi(part.max_hp * final_part_hp_scale), 1)
				if not part.is_destroyed():
					part.hp = part.max_hp
			_final_total += part.max_hp

## node の子の PartsDefeat。なければ null
static func of(node : Node) -> PartsDefeat:
	if node == null:
		return null
	for child in node.get_children():
		if child is PartsDefeat:
			return child
	return null

## 部位が装甲で弾をはじくか(援護が生きているあいだ)
func is_armored() -> bool:
	return _armored

## 部位に入るダメージの倍率(装甲があるあいだは小さい)
func damage_scale() -> float:
	return armored_damage_scale if _armored else 1.0

## はじいた音(続けて当たっても、鳴りすぎないように)
func play_deflect() -> void:
	if deflect_sound == null:
		return
	if _deflect_player == null:
		_deflect_player = AudioStreamPlayer.new()
		_deflect_player.stream = deflect_sound
		_deflect_player.volume_db = deflect_volume_db
		_deflect_player.pitch_scale = 1.9
		add_child(_deflect_player)
	SoundManager.play_on_channel(&"part_deflect", _deflect_player, randf_range(0.95, 1.1))

func _update_armor() -> void:
	var armored := false
	if support_armor:
		for node in get_tree().get_nodes_in_group(support_group):
			if node != _enemy and is_instance_valid(node) and not node.is_queued_for_deletion() \
					and not (node is Enemy and node._is_dead):
				armored = true
				break
	if armored == _armored:
		return
	_armored = armored
	# 装甲が付いた: 水色に光る / なくなった: 赤く光って、壊せるようになった合図
	for part in parts:
		if is_instance_valid(part) and not part.is_destroyed():
			part.pulse(Color(0.8, 1.5, 2.0) if armored else Color(2.2, 1.2, 1.0))

func _physics_process(_delta : float) -> void:
	if _hp == null or _hp.hp <= 0:
		return
	_update_armor()
	var left := 0
	var breakable_left := 0 # 今壊せる部位の残り(段階を待っていて壊せない部位は数えない)
	for part in parts:
		if is_instance_valid(part) and not part.is_destroyed():
			left += maxi(part.hp, 0)
			if part.is_breakable():
				breakable_left += 1
	if _final_mode:
		var target := ceili(float(_final_start_hp) * left / maxf(_final_total, 1.0)) - _final_extra
		if left == 0:
			target = 0 # 全部壊した
		else:
			target = maxi(target, 1) # 砲台が1つでも残っていれば、倒れない(全部壊すまで終わらない)
		if target < _hp.hp:
			_hp.apply_damage(_hp.hp - target)
		return
	if revive_on_phase:
		_revive_old_parts()
		# 段階の途中で(今壊せる部位が)全部壊れたら、少し待って全部直す
		if breakable_left == 0 and not _reviving:
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

## 部位を撃つ以外のダメージ(援護の列車の爆発など)を、本体の HP に与える。
## 最後の段階(部位の残りで HP が決まる)でも、そのぶんだけ HP が減ったままになる。ただし、部位が残っているうちは倒れない
func add_external_damage(amount : int) -> void:
	if _hp == null or _hp.hp <= 0 or amount <= 0:
		return
	if _final_mode:
		_final_extra += amount
		# 最後の段階は、砲台を全部壊すまで倒れない(援護の爆発では、ゲージを 1 まで減らすだけ)
		amount = mini(amount, _hp.hp - 1)
		if amount <= 0:
			return
	_hp.apply_damage(mini(amount, _hp.hp))

## 壊れてから Revive Part Delay 秒たった部位を直す(列車が速く動いているあいだは、止まるまで待つ)
func _revive_old_parts() -> void:
	if revive_part_delay <= 0.0 or _broken_at.is_empty():
		return
	if TrainBossMover.holds_fire(_enemy):
		return
	var now := Time.get_ticks_msec()
	var controller := _controller()
	var phase := controller.current_phase() if controller else 0
	for part in _broken_at.keys():
		if not is_instance_valid(part) or not part.is_destroyed():
			_broken_at.erase(part)
			continue
		if now - int(_broken_at[part]) < revive_part_delay * 1000.0:
			continue
		_broken_at.erase(part)
		part.revive()
		for shooter in part.shooters:
			if is_instance_valid(shooter) and shooter.has_phases():
				shooter.set_phase(phase)

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
