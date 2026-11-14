extends Node
class_name AfterImage
## 速く動いているあいだ、残像を残す部品。敵などの子に置く(突っ込んでくる敵の突進など)。
## 持ち主の Sprite2D(Target)の今の見た目(絵・コマ・向き・大きさ)をコピーして、その場に置き、だんだん消す。

## 残像にする絵。空なら、親の "Sprite2D"
@export var target : Sprite2D
## この速さ(px/秒)より速いときだけ、残像を出す
@export var min_speed : float = 160.0
## 残像を出す間隔と、消えるまでの時間(秒)
@export var interval : float = 0.03
@export var lifetime : float = 0.3
## 残像の色(少し赤く光らせる)
@export var color : Color = Color(1.8, 1.1, 0.7, 0.85)

var _owner2d : Node2D
var _last_pos : Vector2
var _started : bool = false
var _wait : float = 0.0

func _ready() -> void:
	_owner2d = get_parent() as Node2D
	if target == null and _owner2d:
		target = _owner2d.get_node_or_null("Sprite2D") as Sprite2D

func _physics_process(delta : float) -> void:
	if target == null or not is_instance_valid(_owner2d) or delta <= 0.0:
		return
	var pos := _owner2d.global_position
	if not _started:
		_started = true
		_last_pos = pos
		return
	var speed := pos.distance_to(_last_pos) / delta
	_last_pos = pos
	_wait -= delta
	if speed < min_speed or _wait > 0.0 or not target.is_visible_in_tree():
		return
	_wait = interval
	_spawn()

func _spawn() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = target.texture
	ghost.hframes = target.hframes
	ghost.vframes = target.vframes
	ghost.frame = target.frame
	ghost.flip_h = target.flip_h
	ghost.flip_v = target.flip_v
	ghost.offset = target.offset
	ghost.centered = target.centered
	ghost.texture_filter = target.texture_filter
	ghost.material = target.material # ロール(傾き)のシェーダーも同じに
	ghost.modulate = color
	ghost.z_as_relative = false
	ghost.z_index = target.z_index - 1
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = target.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, lifetime)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.85, lifetime)
	tween.tween_callback(ghost.queue_free)
