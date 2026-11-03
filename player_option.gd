extends Node2D
class_name PlayerOption
## 自機の子機(オプション)。パワーアップアイテムで増える。シーン(GameScene/Player/option.tscn)で使う。
## 自機の隣の決まった位置(スロット)へ追いかけて動き、自機が撃つのに合わせて弾を撃つ。
## 低速移動中は自機に寄る。ロックショット中は、ロックした敵を追いかける弾を撃つ。
##
## 見た目: 子の Sprite2D の Texture を差し替える。Texture が空のあいだは、丸を描いて代わりにする。

## 何番目の子機か(0 から)。位置(スロット)を決める
var slot : int = 0

## 子機の位置(自機からの相対位置)。番号の順に増える
@export var slots : Array[Vector2] = [Vector2(-26, 8), Vector2(26, 8), Vector2(-46, 18), Vector2(46, 18)]
## 低速移動中の位置
@export var focus_slots : Array[Vector2] = [Vector2(-16, -2), Vector2(16, -2), Vector2(-28, 6), Vector2(28, 6)]
## 位置へ追いつく速さ(大きいほどぴったり付いてくる)
@export var follow_sharpness : float = 14.0
## 弾1発の威力の、自機のショットに対する倍率
@export var damage_scale : float = 0.6
## 弾の色
@export var shot_color : Color = Color(0.6, 1.0, 0.8)
## 回転の速さ(ラジアン/秒)。0 なら回らない
@export var spin_speed : float = 0.0

var _player : Player

@onready var _sprite : Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func setup(player : Player, index : int) -> void:
	_player = player
	slot = index
	top_level = true # 自機の回転や点滅の影響を受けない(位置は自分で追いかける)
	global_position = player.global_position

func _ready() -> void:
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta : float) -> void:
	if not is_instance_valid(_player):
		return
	visible = _player.visible
	var target := _player.global_position + target_offset()
	global_position = global_position.lerp(target, 1.0 - exp(-follow_sharpness * delta))
	rotation += spin_speed * delta

## 今いるべき位置(自機からの相対位置)
func target_offset() -> Vector2:
	var list := focus_slots if _player.is_focusing else slots
	if list.is_empty():
		return Vector2.ZERO
	return list[slot % list.size()]

## 1発撃つ。target があれば、追いかける弾にする
func fire(bullet_scene : PackedScene, speed : float, damage : float, target : Node2D = null, turn_rate : float = 720.0) -> void:
	if bullet_scene == null or not visible:
		return
	var bullet : Bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.setup(Vector2.UP, speed, damage * damage_scale, 0)
	bullet.modulate = shot_color
	if target:
		bullet.set_homing(target, turn_rate)

## 消える(自機が死んだとき)
func vanish() -> void:
	set_physics_process(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)

## Sprite2D に Texture がないときの、代わりの見た目
func _draw() -> void:
	if _sprite and _sprite.texture:
		return
	draw_circle(Vector2.ZERO, 6.0, Color(0.3, 1.0, 0.7, 0.3))
	draw_circle(Vector2.ZERO, 3.5, Color(0.7, 1.0, 0.9))
