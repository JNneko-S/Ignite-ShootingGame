extends RefCounted
## 炎の演出をまとめた道具(イグナイトの手応え)。使う側は preload して呼ぶ。
##   flame_burst() … 反射弾が敵に当たったところで、炎がぼっと広がる
##   burn_body()   … イグナイトで倒した敵が、炎に包まれて燃える(赤く明滅し、全身から火と黒い煙が出る)

const _BurnPuff := preload("res://GameScene/Effect/burn_puff.gd")
const _SmokePuff := preload("res://GameScene/Effect/smoke_puff.gd")

## at に、炎がぼっと広がる(size は大きさの倍率)
static func flame_burst(tree : SceneTree, at : Vector2, size : float = 1.0) -> void:
	if tree == null:
		return
	var n := 2 + int(size)
	for i in n:
		_BurnPuff.spawn(tree, at + Vector2(randf_range(-8, 8), randf_range(-8, 8)) * size)
	if randf() < 0.5:
		_SmokePuff.spawn(tree, at, 6.0 * size, Vector2(randf_range(-10, 10), -30.0), 0.7, Color(0.18, 0.1, 0.08, 0.5), 4)

## body を seconds 秒のあいだ燃やす(炎と煙を出し続け、赤く明滅させる)。終わるまで待てる
static func burn_body(body : Node2D, seconds : float, radius : float = 16.0) -> void:
	if body == null or not body.is_inside_tree():
		return
	var tree := body.get_tree()
	var base := body.modulate
	var t := 0.0
	var step := 0.045
	while t < seconds and is_instance_valid(body) and body.is_inside_tree():
		var at := body.global_position + Vector2(randf_range(-radius, radius), randf_range(-radius, radius) * 0.8)
		_BurnPuff.spawn(tree, at)
		if randf() < 0.35:
			_SmokePuff.spawn(tree, at, radius * 0.5 + 4.0, Vector2(randf_range(-8, 8), -randf_range(25, 45)), 0.9, Color(0.14, 0.09, 0.08, 0.55), 3)
		var flick := 0.5 + 0.5 * sin(t * 40.0)
		body.modulate = base * Color(1.0 + 0.8 * flick, 0.55 + 0.25 * flick, 0.35, base.a)
		await tree.create_timer(step, false).timeout
		t += step
	if is_instance_valid(body):
		body.modulate = base

## body の見た目の大きさ(半径の目安)
static func body_radius(body : Node2D) -> float:
	var sprite := body.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		var size := sprite.get_rect().size * (sprite.global_scale.abs())
		return clampf(maxf(size.x, size.y) * 0.4, 8.0, 70.0)
	return 16.0
