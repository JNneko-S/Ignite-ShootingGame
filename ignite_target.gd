extends Node2D
class_name IgniteTarget
## イグナイトでだけ壊せる、背景のオブジェクト(貨車など)。シーン(GameScene/Prop/ignite_target.tscn)で使う。
## ショットや弾は当たらない。イグナイトの焼却範囲に入ると燃えて壊れ、スコアアイテムを落とす。
## 背景のスプライトの子として出す(PropEvent)と、背景と一緒に流れる。
##
## 見た目: intact_textures と broken_textures の同じ番号が組になる。variant が -1 なら、ランダムに選ぶ。

@export var intact_textures : Array[Texture2D] = []
@export var broken_textures : Array[Texture2D] = []
## 使う組の番号。-1 ならランダム
@export var variant : int = -1

@export_group("スコア")
## 落とすアイテムの点数の合計と、個数
@export var item_total : int = 3000
@export var item_count : int = 10

@export_group("判定")
## 焼却範囲の円が、中心からこの距離(px、画面の大きさ)まで来たら壊れる
@export var hit_radius : float = 28.0

@export_group("見た目")
## 壊せることが分かるように、ゆっくり光らせる色(壊れたら止まる)
@export var glow_color : Color = Color(1.35, 1.1, 0.85)
@export var glow_period : float = 1.2
@export var explosion_scale : float = 1.4
@export var break_sound : AudioStream = preload("res://Assets/Sounds/Explosive/AS_1474525_爆発01-1（短）.mp3")
@export var break_sound_db : float = -12.0

var _broken : bool = false
var _variant : int = 0
var _age : float = 0.0

@onready var _sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	if not intact_textures.is_empty():
		_variant = variant if variant >= 0 else randi() % intact_textures.size()
		_variant = clampi(_variant, 0, intact_textures.size() - 1)
		_sprite.texture = intact_textures[_variant]

func _physics_process(delta : float) -> void:
	var area := CameraView.visible_rect(self)
	if global_position.y > area.end.y + 200.0:
		queue_free() # 画面の下へ流れ去った
		return
	if _broken:
		return
	_age += delta
	_sprite.modulate = Color.WHITE.lerp(glow_color, 0.5 - 0.5 * cos(_age * TAU / glow_period))
	if global_position.y < area.position.y - 40.0:
		return # まだ画面に入っていない
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.is_igniting or player.ignite_aura == null:
		return
	var reach := player.ignite_aura.current_radius() + hit_radius
	if reach > hit_radius and global_position.distance_to(player.global_position) <= reach:
		_break()

func _break() -> void:
	_broken = true
	_sprite.modulate = Color(3.0, 2.2, 1.4)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.4)
	if _variant < broken_textures.size() and broken_textures[_variant]:
		_sprite.texture = broken_textures[_variant]
	Explosion.spawn(get_tree(), Explosion.EXPLOSIVE, global_position, explosion_scale)
	if break_sound:
		SoundManager.play_sfx(break_sound, break_sound_db)
	var score_system := get_tree().get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.spawn_items(global_position, item_total, item_count, 1.5)
