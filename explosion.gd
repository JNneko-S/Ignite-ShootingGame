extends RefCounted
class_name Explosion
## 爆発エフェクト(GameScene/Effect の .tscn)を、その場に出して再生し、終わったら消す。
## エフェクトのシーンは、Sprite2D と AnimationPlayer があれば何でもよい(自動再生でなくてもよい)。

const ZAKO : PackedScene = preload("res://GameScene/Effect/zako_explosion_effect.tscn")
const EXPLOSIVE : PackedScene = preload("res://GameScene/Effect/explosive_effect.tscn")
const WAVE : PackedScene = preload("res://GameScene/Effect/boss_expolsion.tscn")
## 全ての爆発エフェクト(ボスの連鎖爆発で順番に使う)
const ALL : Array[PackedScene] = [ZAKO, EXPLOSIVE, WAVE]

## 敵弾より手前に出す
const Z_INDEX : int = 8

## scene を position に出して再生する。parent が null なら現在のシーンの直下に出す
static func spawn(tree : SceneTree, scene : PackedScene, position : Vector2, scale : float = 1.0, parent : Node = null) -> Node2D:
	if scene == null or tree == null or tree.current_scene == null:
		return null
	var effect := scene.instantiate() as Node2D
	(parent if parent else tree.current_scene).add_child(effect)
	effect.global_position = position
	effect.scale = Vector2.ONE * scale
	effect.rotation = randf() * TAU
	effect.z_index = Z_INDEX
	var player := effect.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var animation := _main_animation(player)
	if animation == "":
		effect.get_tree().create_timer(2.0).timeout.connect(effect.queue_free)
		return effect
	player.play(animation)
	player.animation_finished.connect(func(_name : StringName) -> void: effect.queue_free())
	return effect

## RESET 以外の最初のアニメーション
static func _main_animation(player : AnimationPlayer) -> StringName:
	if player == null:
		return ""
	for animation in player.get_animation_list():
		if animation != &"RESET":
			return animation
	return ""
