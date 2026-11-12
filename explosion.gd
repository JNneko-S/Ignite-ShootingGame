extends RefCounted
class_name Explosion
## 爆発エフェクト(GameScene/Effect の .tscn)を、その場に出して再生し、終わったら消す。
## エフェクトのシーンは、Sprite2D と AnimationPlayer があれば何でもよい(自動再生でなくてもよい)。

const ZAKO : PackedScene = preload("res://GameScene/Effect/zako_explosion_effect.tscn")
const EXPLOSIVE : PackedScene = preload("res://GameScene/Effect/explosive_effect.tscn")
const WAVE : PackedScene = preload("res://GameScene/Effect/boss_expolsion.tscn")
## 全ての爆発エフェクト(ボスの連鎖爆発で順番に使う)
const ALL : Array[PackedScene] = [ZAKO, EXPLOSIVE, WAVE]

## フィールド(背景)と地上の敵(戦車など z 1)の上、空の敵(z 2)・敵弾(z 5)の下に出す。
## 地上の敵と同じ 1 だが、あとからシーンに足すので、その上に描かれる
const Z_INDEX : int = 1

## 爆発のアニメーションを再生する速さの倍率。大きいほど早く消える(たくさん出しても画面に残らない)。
## 1 で元の速さ(約1.6秒)。2.4 なら約0.7秒で消える
static var speed : float = 2.4

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
	player.play(animation, -1.0, speed)
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

## at の周り(半径 radius の中)に、小さな爆発を count 個、少しずつ遅らせてばらまく。
## 敵が先に消えても続くよう、どのノードにも紐づかない Tween で進める
## pattern で並べ方を選ぶ(BurstPattern)。RANDOM なら、毎回どれかをランダムに選ぶ
static func burst(tree : SceneTree, at : Vector2, count : int, radius : float, scale : float = 0.7,
		interval : float = 0.03, pattern : BurstPattern = BurstPattern.RANDOM) -> void:
	if tree == null or count <= 0:
		return
	if pattern == BurstPattern.RANDOM:
		pattern = [BurstPattern.SCATTER, BurstPattern.ARC, BurstPattern.CLOCKWISE, BurstPattern.FAN].pick_random()
	var points := _burst_points(at, count, radius, pattern)
	if pattern != BurstPattern.SCATTER:
		interval *= 1.5 # 順番に並ぶ形は、少しゆっくり出して、流れが見えるようにする
	var tween := tree.create_tween()
	for i in points.size():
		var point : Vector2 = points[i]
		var scene : PackedScene = EXPLOSIVE if i % 2 == 0 else ZAKO
		var t := float(i) / maxf(points.size() - 1, 1.0)
		var effect_scale := scale * randf_range(0.85, 1.15)
		if pattern == BurstPattern.ARC:
			effect_scale *= lerpf(1.2, 0.7, t) # 先へ行くほど小さく
		tween.tween_interval(interval)
		tween.tween_callback(func() -> void: spawn(tree, scene, point, effect_scale))

## 周りにばらまく小さな爆発の並べ方
##   SCATTER  : 周りにばらばらに
##   ARC      : 少し曲がった線に沿って、手前から先へ順番に(向きと曲がる側はランダム)
##   CLOCKWISE: 時計回りに、ばばばっと一周
##   FAN      : ランダムな向きへ、扇の形に広がる
enum BurstPattern { RANDOM, SCATTER, ARC, CLOCKWISE, FAN }

static func _burst_points(at : Vector2, count : int, radius : float, pattern : BurstPattern) -> Array[Vector2]:
	var points : Array[Vector2] = []
	var start := randf() * TAU
	match pattern:
		BurstPattern.ARC:
			var n := count + 1
			var direction := Vector2.from_angle(start)
			var length := radius * 2.4
			var bend := direction.orthogonal() * length * randf_range(0.25, 0.45) * (1.0 if randf() < 0.5 else -1.0)
			var from := at - direction * length * 0.2 # 少し手前から始めて、敵の体を通り抜ける
			var control := from + direction * length * 0.5 + bend
			var end := from + direction * length
			for i in n:
				var t := float(i) / maxf(n - 1, 1.0)
				points.append(from.lerp(control, t).lerp(control.lerp(end, t), t)) # 2次ベジェ曲線
		BurstPattern.CLOCKWISE:
			var n2 := count + 2
			for i in n2:
				# 画面では y が下向きなので、角度を増やすと時計回りになる
				points.append(at + Vector2.from_angle(start + TAU * i / n2) * radius * 0.85)
		BurstPattern.FAN:
			var half := deg_to_rad(55.0)
			for i in count:
				var t2 := float(i) / maxf(count - 1, 1.0)
				var angle2 := start + lerpf(-half, half, t2)
				points.append(at + Vector2.from_angle(angle2) * radius * randf_range(0.8, 1.2))
		_:
			for i in count:
				# ぐるっと一周するように置いて、偏らないようにする(距離はばらす)
				var angle := start + TAU * (float(i) + randf_range(-0.3, 0.3)) / count
				points.append(at + Vector2.from_angle(angle) * radius * randf_range(0.45, 1.0))
	return points

## 並べ方: 曲線(どこかへ曲がりながら伸びる) / 円(ぐるっと一周) / 渦巻き(回りながら外へ広がる)
enum ChainShape { CURVE, CIRCLE, SPIRAL }

## 近距離で倒したときの豪華な爆発。並べ方は、曲線・円・渦巻きからランダムに選ぶ
static func random_chain(tree : SceneTree, from : Vector2, size : float = 1.0, interval : float = 0.025,
		base_scale : float = 1.0, sound : AudioStreamPlayer = null, volume_offset_db : float = 0.0) -> void:
	var shape : ChainShape = [ChainShape.CURVE, ChainShape.CIRCLE, ChainShape.SPIRAL].pick_random()
	chain(tree, from, shape, size, interval, base_scale, sound, volume_offset_db)

## 爆発を、shape の形に並べて順番に起こす。size は形の大きさの倍率(1 で、半径・長さが約 50〜110px)。
## 敵が先に消えても続くよう、どのノードにも紐づかない Tween で進める
static func chain(tree : SceneTree, from : Vector2, shape : ChainShape, size : float = 1.0, interval : float = 0.025,
		base_scale : float = 1.0, sound : AudioStreamPlayer = null, volume_offset_db : float = 0.0) -> void:
	if tree == null:
		return
	var points := _chain_points(from, shape, size)
	var sound_copy := SoundManager.copy_of(sound) # 敵が先に消えても鳴るように、音の設定を写しておく
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
			if with_sound:
				SoundManager.play_copy(sound_copy, pitch, volume_offset_db))
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
