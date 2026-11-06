extends RefCounted
class_name Explosion
## 爆発エフェクト(GameScene/Effect の .tscn)を、その場に出して再生し、終わったら消す。
## エフェクトのシーンは、Sprite2D と AnimationPlayer があれば何でもよい(自動再生でなくてもよい)。

const ZAKO : PackedScene = preload("res://GameScene/Effect/zako_explosion_effect.tscn")
const EXPLOSIVE : PackedScene = preload("res://GameScene/Effect/explosive_effect.tscn")
const WAVE : PackedScene = preload("res://GameScene/Effect/boss_expolsion.tscn")
## 全ての爆発エフェクト(ボスの連鎖爆発で順番に使う)
const ALL : Array[PackedScene] = [ZAKO, EXPLOSIVE, WAVE]

## フィールド(背景)の上、敵・敵弾・自機の下に出す。背景と同じ 0 だが、背景より後にシーンへ足すので、背景の上に描かれる
const Z_INDEX : int = 0

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

## 並べ方: 曲線(どこかへ曲がりながら伸びる) / 円(ぐるっと一周) / 渦巻き(回りながら外へ広がる)
enum ChainShape { CURVE, CIRCLE, SPIRAL }

## 近距離で倒したときの豪華な爆発。並べ方は、曲線・円・渦巻きからランダムに選ぶ
static func random_chain(tree : SceneTree, from : Vector2, size : float = 1.0, interval : float = 0.025,
		base_scale : float = 1.0, sound : AudioStream = null, sound_db : float = -20.0) -> void:
	var shape : ChainShape = [ChainShape.CURVE, ChainShape.CIRCLE, ChainShape.SPIRAL].pick_random()
	chain(tree, from, shape, size, interval, base_scale, sound, sound_db)

## 爆発を、shape の形に並べて順番に起こす。size は形の大きさの倍率(1 で、半径・長さが約 50〜110px)。
## 敵が先に消えても続くよう、どのノードにも紐づかない Tween で進める
static func chain(tree : SceneTree, from : Vector2, shape : ChainShape, size : float = 1.0, interval : float = 0.025,
		base_scale : float = 1.0, sound : AudioStream = null, sound_db : float = -20.0) -> void:
	if tree == null:
		return
	var points := _chain_points(from, shape, size)
	var tween := tree.create_tween()
	for i in points.size():
		var t := float(i + 1) / float(points.size())
		var point : Vector2 = points[i]
		# 曲線は真ん中が、渦巻きは外ほど、円はどれも同じくらいの大きさ
		var grow := 0.7 + 0.8 * sin(t * PI)
		if shape == ChainShape.SPIRAL:
			grow = 0.6 + 0.9 * t
		elif shape == ChainShape.CIRCLE:
			grow = 1.0
		var effect_scale := base_scale * grow * randf_range(0.85, 1.15)
		var scene : PackedScene = ZAKO if i % 2 == 0 else EXPLOSIVE
		var pitch := 0.9 + 0.5 * t # 先へ行くほど音が高くなる
		var with_sound := i % 2 == 0 # 音は1つおき(重なりすぎないように)
		tween.tween_callback(func() -> void:
			spawn(tree, scene, point, effect_scale)
			if sound and with_sound:
				SoundManager.play_sfx(sound, sound_db, pitch))
		tween.tween_interval(interval)

static func _chain_points(from : Vector2, shape : ChainShape, size : float) -> Array[Vector2]:
	var points : Array[Vector2] = []
	var turn := 1.0 if randf() < 0.5 else -1.0 # 回る向き
	var start := randf() * TAU
	match shape:
		ChainShape.CURVE:
			var length := 110.0 * size
			var direction := Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05)) # 上向きのどこか
			var side := direction.orthogonal() * randf_range(-1.0, 1.0) * length * 0.7
			var control := from + direction * length * 0.5 + side
			var end := from + direction * length + side * 0.4
			for i in 7:
				var t := float(i + 1) / 7.0
				points.append(from.lerp(control, t).lerp(control.lerp(end, t), t)) # 2次ベジェ曲線
		ChainShape.CIRCLE:
			var radius := 46.0 * size
			for i in 10:
				points.append(from + Vector2.from_angle(start + turn * TAU * i / 10.0) * radius)
		ChainShape.SPIRAL:
			for i in 12:
				var t := float(i) / 11.0
				var radius := lerpf(8.0, 78.0, t) * size
				points.append(from + Vector2.from_angle(start + turn * TAU * 1.6 * t) * radius) # 1周半しながら広がる
	return points
