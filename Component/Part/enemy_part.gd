extends Node2D
class_name EnemyPart
## 敵の部位(分離型の中ボスの砲台、戦車の砲塔など)。自分の HP を持ち、壊れると、その部位の砲口(EnemyShooter)が止まる。
##
## 使い方:
##   敵のシーンに Node2D を追加して、このスクリプトをアタッチする。子に次を置く
##     ・Hurtbox(Hurtbox か ArmorHurtbox。子に CollisionShape2D と Timer)
##     ・EnemyShooter(この部位の砲口。いくつでも)
##     ・Sprite2D(見た目。壊れると暗くなって消える)
##   砲口が部位の子にない(本体から継承した砲口など)ときは、Shooters に入れる

signal destroyed(part : EnemyPart)

@export var max_hp : int = 400
## 部位が受けたダメージのうち、この割合を本体(Enemy の HPComponent)にも与える
@export_range(0.0, 1.0, 0.05) var damage_to_body : float = 0.25
## 子でない砲口のうち、壊れたときに止めるもの
@export var shooters : Array[EnemyShooter] = []
## ボスのこの段階(0 から数える。1 なら第二形態)に入るまでは壊れない。弾は受け止めるが、この部位の HP は減らない
## (本体へのダメージ Damage To Body は入る)。0 なら最初から壊せる
@export var breakable_from_phase : int = 0

@export_group("壊れたとき")
## 壊れたときの爆発の大きさ(0 なら爆発しない)
@export var break_explosion_scale : float = 1.4
## 壊れたときに落とすスコアアイテムの点数の合計と個数(0 なら落とさない)
@export var break_score : int = 0
@export var break_items : int = 6
## 壊れたときに有効にする当たり判定(本体の、この部位に隠れていた部分など)。最初は Disabled にしておく
@export var reveal_on_destroy : Array[CollisionShape2D] = []

var hp : int = 0
var _destroyed : bool = false
var _breakable : bool = true
var _flash_tween : Tween

func _ready() -> void:
	hp = max_hp
	_breakable = breakable_from_phase <= 0
	for node in find_children("*", "Area2D", true, false):
		if node is Hurtbox:
			node.recieved_damage.connect(_on_damage)
			if not node.area_entered.is_connected(node._on_area_entered):
				node.area_entered.connect(node._on_area_entered)
	if not _breakable:
		_watch_phase.call_deferred() # ボスの段階の管理(BossPhaseController)が付くのを待つ

func is_destroyed() -> bool:
	return _destroyed

## 今、壊せるか(ボスの段階を待っているあいだは false)
func is_breakable() -> bool:
	return _breakable

## ボスの段階が breakable_from_phase に入ったら、壊せるようにする
func _watch_phase() -> void:
	var body := _body()
	var controller : BossPhaseController = null
	if body:
		for child in body.get_children():
			if child is BossPhaseController:
				controller = child
	if controller == null:
		_set_breakable() # 段階のない敵なら、最初から壊せる
		return
	controller.phase_started.connect(func(index : int) -> void:
		if index >= breakable_from_phase:
			_set_breakable())

func _set_breakable() -> void:
	if _breakable or _destroyed:
		return
	_breakable = true
	# 壊せるようになった合図: 赤く光って戻る
	var tween := create_tween()
	modulate = Color(2.2, 1.2, 1.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.4)

func _on_damage(damage : float, _knockback_dir : Vector2 = Vector2.ZERO) -> void:
	if _destroyed:
		return
	var body := _body()
	if body and damage_to_body > 0.0:
		body.hp_component.apply_damage(ceili(damage * damage_to_body))
	if not _breakable:
		_flash(Color(1.15, 1.15, 1.25)) # 壊せないあいだは、弱く光るだけ(弾を弾いている)
		return
	hp -= ceili(damage)
	if hp <= 0:
		_destroy()
	else:
		_flash()

func _destroy() -> void:
	_destroyed = true
	var stopped : Array = shooters.duplicate()
	for node in find_children("*", "", true, false):
		if node is EnemyShooter:
			stopped.append(node)
		elif node is Hurtbox:
			node.set_deferred("monitoring", false)
			node.set_deferred("monitorable", false)
	for shooter in stopped:
		if is_instance_valid(shooter):
			shooter.enabled = false
			shooter.stop()
	for shape in reveal_on_destroy:
		if is_instance_valid(shape):
			shape.set_deferred("disabled", false)
	if break_explosion_scale > 0.0:
		Explosion.spawn(get_tree(), Explosion.EXPLOSIVE, global_position, break_explosion_scale)
	if break_score > 0:
		var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
		if score_system:
			score_system.spawn_items(global_position, break_score, break_items, 1.3)
	destroyed.emit(self)
	# 光ってから、暗くなって縮む
	var tween := create_tween()
	modulate = Color(2.0, 1.6, 1.2)
	tween.tween_property(self, "modulate", Color(0.35, 0.3, 0.3, 0.0), 0.5)
	tween.parallel().tween_property(self, "scale", scale * 0.6, 0.5)

func _flash(color : Color = Color(1.8, 1.8, 1.8)) -> void:
	if _flash_tween and _flash_tween.is_running():
		return
	_flash_tween = create_tween()
	modulate = color
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08)

func _body() -> Enemy:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node
		node = node.get_parent()
	return null
