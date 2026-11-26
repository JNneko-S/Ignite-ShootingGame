extends Area2D
class_name Hurtbox
## (新しく足したクラスは、エディタがクラス名を覚える前でも動くように、ファイルを直接読み込んで使う)
const _HitSpark := preload("res://GameScene/Effect/hit_spark.gd")
const _FireFx := preload("res://GameScene/Effect/fire_fx.gd")

@export var character : CharacterBody2D

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var cool_down: Timer = $Timer

var current_area : Area2D
## 最後にダメージを与えてきた Hitbox(被弾の向きを調べるのに使う)。もう消えていることもある
var last_hitbox : Hitbox
## 最後にダメージを受けた時刻(ミリ秒。部位がいくつもある敵で、とどめを刺した当たり判定を探すのに使う)
var last_hit_msec : int = 0

signal recieved_damage(damage : int)

## 被弾の火花を出す間隔(秒)。連射で同じ敵に当たり続けても、火花が出すぎないように
const HIT_SPARK_INTERVAL_MSEC : int = 45
var _last_spark_msec : int = -1000

func _apply_damage(hitbox : Hitbox) -> void:
	if hitbox:
		last_hitbox = hitbox
		last_hit_msec = Time.get_ticks_msec()
		# 自機・子機のショットで敵に当てた(イグナイトの反射弾は、敵の弾なので数えない)。実績「イグナイトオンリー」に使う
		if hitbox is Bullet and not (hitbox is EnemyBullet) and hitbox.damage_source_type == Hitbox.DamageSourceType.Player:
			RunConfig.shot_damage_used = true
			RunConfig.stage_shot_damage_used = true
		recieved_damage.emit(_scaled_damage(hitbox))
		_hit_spark(hitbox)
		hitbox.damage_dealt.emit(self)

## 自機の弾(反射弾も)が敵に当たったら、当たった所に火花を出す(撃った側へ散る)
func _hit_spark(hitbox : Hitbox) -> void:
	if hitbox.damage_source_type != Hitbox.DamageSourceType.Player or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - _last_spark_msec < HIT_SPARK_INTERVAL_MSEC:
		return
	_last_spark_msec = now
	var away := hitbox.global_position - global_position
	_HitSpark.spawn(get_tree(), hitbox.global_position, away if away.length_squared() > 1.0 else Vector2.UP,
			1.4 if hitbox is EnemyBullet else 1.0)
	if hitbox is EnemyBullet:
		_FireFx.flame_burst(get_tree(), hitbox.global_position, 1.0) # 反射弾(イグナイト)の手応え: 当たったところが炎上する

## 自機のショットは、自機が近くにいるほど強くなる(Player.close_damage_scale_at)。
## ダメージは整数なので、端数は確率で切り上げて、平均が倍率どおりになるようにする
func _scaled_damage(hitbox : Hitbox) -> int:
	var damage := hitbox.damage
	if hitbox is EnemyBullet and hitbox.damage_source_type == Hitbox.DamageSourceType.Player:
		# カウンター弾を返して当てた: その敵の最大HPの決まった割合を、一気に削る
		var counter : float = (hitbox as EnemyBullet).counter_hp_ratio
		if counter > 0.0:
			var owner_enemy := _owner_enemy()
			if owner_enemy and owner_enemy.hp_component:
				var big := roundi(owner_enemy.hp_component.max_hp * counter * HazardRank.reflect_damage_scale(self))
				_counter_break(owner_enemy, hitbox.global_position, big)
				owner_enemy.hp_component.counter_pass = true # カウンター大技のあいだのロックも素通り
				owner_enemy.hp_component.apply_damage(big) # 部位に当たっても、本体を削る
				return 1
		# イグナイトの反射弾: ANOTHER のボス・中ボスには、効きにくい(端数は確率で切り上げ)
		var scale := HazardRank.reflect_damage_scale(self)
		if scale < 1.0:
			var scaled_reflect := damage * scale
			var whole_reflect := floori(scaled_reflect)
			return maxi(whole_reflect + (1 if randf() < scaled_reflect - whole_reflect else 0), 1)
		return damage
	if not (hitbox is Bullet) or hitbox.damage_source_type != Hitbox.DamageSourceType.Player:
		return damage
	var base : float = (hitbox as Bullet).damage_against(self) # 中心ねらいの弾は、当たった所で威力が変わる
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("close_damage_scale_at"):
		return maxi(roundi(base), 1)
	var bonus : float = player.close_damage_scale_at(global_position)
	var scaled := base * bonus
	var whole := floori(scaled)
	return maxi(whole + (1 if randf() < scaled - whole else 0), 1)

func apply_extra_damage(amount : float) -> void:
	recieved_damage.emit(amount, Vector2.ZERO)

## 持ち主(Character)が ignores_hit(area) で true を返したら、その弾には当たらない(自機の、理不尽な被弾を防ぐ)
func _ignored(area : Area2D) -> bool:
	return character != null and character.has_method("ignores_hit") and character.ignores_hit(area)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and not _ignored(area):
		current_area = area
		_apply_damage(area)

func _on_area_exited(area: Area2D) -> void:
	if area == current_area:
		current_area = null
		cool_down.stop()

func _on_cool_down_timeout() -> void:
	if current_area == null or _ignored(current_area):
		return
	
	_apply_damage(current_area)

## この当たり判定の持ち主の敵(部位の当たり判定なら、その部位を持つ敵)
func _owner_enemy() -> Enemy:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node
		node = node.get_parent()
	return null

## カウンター大技を返した: 「COUNTER BREAK!」と出て、炎が大きく広がり、画面が揺れて、点が入る
func _counter_break(enemy : Enemy, at : Vector2, damage : int) -> void:
	var tree := get_tree()
	_FireFx.flame_burst(tree, at, 2.6)
	FloatingText.spawn(tree, at + Vector2(0, -24), "COUNTER BREAK!", Color(1.0, 0.55, 0.15), 18)
	HitStop.apply(tree, 0.12)
	ScreenFlash.play(tree, 0.25)
	var camera := StageCamera.of(enemy)
	if camera:
		camera.shake(6.0, 0.3)
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.add_points(20000, at)
	if enemy.has_method("on_counter_break"):
		enemy.on_counter_break(damage)
