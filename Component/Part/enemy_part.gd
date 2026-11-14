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
## 壊れたときの音(シーンに置いた AudioStreamPlayer)。空なら、本体の DeathExplosion の音を少し高くして鳴らす
@export var break_sound : AudioStreamPlayer
## 壊れたあとの見た目。FADE: 暗くなって縮んで消える / DARKEN: 黒くなって、その場に残る(列車の砲台など。revive() で直せる)
enum DestroyedLook { FADE, DARKEN }
@export var destroyed_look : DestroyedLook = DestroyedLook.FADE
## DARKEN のときの色
@export var destroyed_color : Color = Color(0.22, 0.2, 0.2)
## 壊れたときに有効にする当たり判定(本体の、この部位に隠れていた部分など)。最初は Disabled にしておく
@export var reveal_on_destroy : Array[CollisionShape2D] = []

var hp : int = 0
var _destroyed : bool = false
## 壊れる前に、ロックオンの対象("lock_target" グループ)だったか(直したときに戻す)
var _was_lock_target : bool = false
var _breakable : bool = true
var _flash_tween : Tween

## 狙える(ロックオン・反射弾の追尾)ものを全部返す:
##   ・"enemy" グループの敵(ただし "no_lock" グループのもの = 部位だけを狙わせたい本体 は除く)
##   ・"lock_target" グループの部位(壊せるあいだだけ)
static func targets(tree : SceneTree) -> Array[Node2D]:
	var result : Array[Node2D] = []
	for node in tree.get_nodes_in_group("enemy"):
		if node is Node2D and not node.is_in_group("no_lock"):
			result.append(node)
	for node in tree.get_nodes_in_group("lock_target"):
		var part := node as EnemyPart
		if part and not part.is_destroyed() and part.is_breakable():
			result.append(part)
	return result

## まだ狙ってよいか(ロックを外すかどうか)
static func is_target(node : Node2D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
		return false
	if node is EnemyPart:
		return not node.is_destroyed() and node.is_in_group("lock_target")
	return node.is_in_group("enemy") and not node.is_in_group("no_lock")

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
	_was_lock_target = is_in_group("lock_target")
	remove_from_group("lock_target")
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
	_play_break_sound()
	if break_score > 0:
		var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
		if score_system:
			score_system.spawn_items(global_position, break_score, break_items, 1.3)
	destroyed.emit(self)
	var tween := create_tween()
	modulate = Color(2.0, 1.6, 1.2)
	if destroyed_look == DestroyedLook.DARKEN:
		# 光ってから、黒くなって、その場に残る(動かない・撃たない)
		tween.tween_property(self, "modulate", destroyed_color, 0.5)
	else:
		# 光ってから、暗くなって縮む
		tween.tween_property(self, "modulate", Color(0.35, 0.3, 0.3, 0.0), 0.5)
		tween.parallel().tween_property(self, "scale", scale * 0.6, 0.5)

## 壊れた部位を直す(ボスの段階が変わったときなど)。HP を戻し、また撃てて、当たるようにする。
## 砲口の弾幕は、呼ぶ側が入れ直す(BossPhaseController が段階の弾幕に切り替える)
func revive() -> void:
	if not _destroyed:
		return
	_destroyed = false
	hp = max_hp
	if _was_lock_target:
		add_to_group("lock_target")
	var revived : Array = shooters.duplicate()
	for node in find_children("*", "", true, false):
		if node is EnemyShooter:
			revived.append(node)
		elif node is Hurtbox:
			node.set_deferred("monitoring", true)
			node.set_deferred("monitorable", true)
	for shooter in revived:
		if is_instance_valid(shooter):
			shooter.enabled = true
	# 白く光って、元の色に戻る(直った合図)
	var tween := create_tween()
	modulate = Color(2.2, 2.2, 2.4)
	tween.tween_property(self, "modulate", Color.WHITE, 0.6)

func _play_break_sound() -> void:
	if break_sound:
		SoundManager.play(break_sound)
		return
	var body := _body()
	var death := DeathExplosion.of(body) if body else null
	if death and death.sound:
		SoundManager.play(death.sound, randf_range(1.05, 1.2)) # 本体が倒れたときの音より、少し高く軽く

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
