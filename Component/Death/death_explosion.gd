extends Node
class_name DeathExplosion
## 倒されたときの爆発の部品。持ち主(親の Node2D)の子に置いて、await play() する。終わったら持ち主を消してよい。
##
## big がオフ: その場で1回爆発して、すぐ終わる(雑魚)
## big がオン : 撃つのをやめ、全ての爆発エフェクトを順番に体中で起こしてから、大爆発する(中型・ボス)

@export_group("爆発")
## その場に出す爆発。空なら爆発しない
@export var explosion_scene : PackedScene = Explosion.ZAKO
@export var explosion_scale : float = 1.0
## 効果音(シーンに置いた AudioStreamPlayer。音量・高さはノードで決める)。空なら鳴らさない
@export var sound : AudioStreamPlayer
## その場の爆発に加えて、周りにばらまく小さな爆発の数(0 なら出さない)
@export var extra_count : int = 4
## ばらまく範囲の半径(px)と、小さな爆発の大きさ
@export var extra_radius : float = 26.0
@export var extra_scale : float = 0.65
## 小さな爆発を出していく間隔(秒)
@export var extra_interval : float = 0.03

@export_group("連鎖爆発 → 大爆発")
## オンなら、連鎖爆発 → 大爆発してから終わる。ボスは StageRunner が is_boss の敵をオンにする
@export var big : bool = false
## 連鎖爆発を出す範囲(持ち主の位置からのずれ)。大きさが 0 なら、持ち主の Sprite2D の見た目の範囲を使う
@export var area : Rect2 = Rect2()
## 連鎖爆発の回数と、かける時間(秒)
@export var count : int = 15
@export var duration : float = 2.2
## オンなら、連鎖爆発の始めに画面の敵弾を燃やして消す(ボス用)。中型機はオフにして、弾は残す
@export var burn_bullets : bool = true
## 連鎖爆発のあいだに、この距離(px)だけ流されていく(力尽きて落ちていく感じ)。0 ならその場で爆発
@export var drift : Vector2 = Vector2.ZERO
## 揺れの強さの倍率(中型機は小さめにする)
@export var shake_scale : float = 1.0
## 大爆発の効果音(AudioStreamPlayer)
@export var big_sound : AudioStreamPlayer

@export_group("イグナイト中の撃破(大きめの爆発)")
## 持ち主の ignite_kill がオンのとき(イグナイトの発動中に倒したとき)は、爆発が大きめになる:
##   ・真ん中の爆発が Ignite Scale Boost 倍になる
##   ・周りにばらまく爆発が増えて、広がる(Ignite Extra Count 個、半径 Ignite Extra Radius)
@export var ignite_scale_boost : float = 1.9
@export var ignite_extra_count : int = 10
@export var ignite_extra_radius : float = 58.0
@export var ignite_extra_scale : float = 1.0

@export_group("近距離撃破(並んだ爆発)")
## 持ち主の close_kill がオンのとき(近づいて撃って倒したとき)は、いつもの爆発に加えて、
## 曲線・円・渦巻きのどれかに並んだ爆発が起こる。イグナイトの発動中なら、大きめの爆発と両方起こる
## 形の大きさの倍率(1 で、半径・長さが約 50〜110px)
@export var close_chain_size : float = 1.0
## 爆発と爆発の間隔(秒)。小さいほど速く並ぶ
@export var close_chain_interval : float = 0.025
## 爆発1つの大きさ
@export var close_chain_scale : float = 1.1


## 爆発させる。big のときは、大爆発と持ち主のフェードが終わるまで待てる
func play() -> void:
	var body := get_parent() as Node2D
	if body == null:
		return
	var close : bool = body.get("close_kill") == true
	var ignite : bool = body.get("ignite_kill") == true
	if close:
		Explosion.random_chain(get_tree(), body.global_position, close_chain_size,
			close_chain_interval, close_chain_scale, sound, -6.0)
	if not big:
		if explosion_scene:
			var effect_scale := explosion_scale * (ignite_scale_boost if ignite else 1.0)
			Explosion.spawn(get_tree(), explosion_scene, body.global_position, effect_scale)
			if ignite:
				Explosion.burst(get_tree(), body.global_position, ignite_extra_count,
					ignite_extra_radius * explosion_scale, ignite_extra_scale * explosion_scale, extra_interval)
			else:
				Explosion.burst(get_tree(), body.global_position, extra_count,
					extra_radius * explosion_scale, extra_scale * explosion_scale, extra_interval)
		if sound:
			SoundManager.play(sound)
		return
	await _play_big(body)

func _play_big(body : Node2D) -> void:
	_disable(body)
	if burn_bullets:
		get_tree().call_group("enemy_bullet", "burn") # 画面の敵弾は燃えて消える
	if drift != Vector2.ZERO:
		# 力尽きて、連鎖爆発のあいだ流されていく
		var move := body.create_tween()
		move.tween_property(body, "position", body.position + drift, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var tree := get_tree()
	var rect := _area_of(body)
	# 大爆発の大きさは、見た目の大きさに合わせる(中ボスは小さめ、ボスは大きめ)
	var big_scale := clampf(rect.size.length() / 90.0, 2.0, 6.0)
	var interval := duration / maxi(count, 1)
	for i in count:
		var offset := rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
		var scene : PackedScene = Explosion.ALL[i % Explosion.ALL.size()]
		var effect_scale := randf_range(1.2, 2.0) * (0.6 if scene == Explosion.WAVE else 1.0) # 衝撃波は白く大きいので控えめ
		Explosion.spawn(tree, scene, body.global_position + offset, effect_scale)
		Explosion.burst(tree, body.global_position + offset, 3, 30.0, 0.8, 0.03) # 1回ごとに、周りにも小さな爆発
		if sound:
			SoundManager.play(sound, randf_range(0.9, 1.1), -4.0) # 連鎖の音は少し小さく、高さをばらす
		SpriteShake.shake(body, 4.0 * shake_scale)
		await tree.create_timer(interval).timeout

	# 大爆発: 中心に大きな爆発と衝撃波、周りに小さな爆発
	var center := body.global_position + rect.get_center()
	Explosion.spawn(tree, Explosion.EXPLOSIVE, center, big_scale)
	if big_sound:
		SoundManager.play(big_sound)
	Explosion.spawn(tree, Explosion.WAVE, center, big_scale * 0.8)
	for i in 8:
		Explosion.spawn(tree, Explosion.ZAKO, center + Vector2.from_angle(TAU * i / 8.0) * rect.size.length() * 0.25, big_scale * 0.5)
	SpriteShake.shake(body, 12.0 * shake_scale)
	var fade := body.create_tween()
	fade.tween_property(body, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.08)
	fade.tween_property(body, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	await fade.finished

## 撃つのをやめ、当たり判定(部位も含めて)を消す
func _disable(body : Node) -> void:
	for node in body.find_children("*", "", true, false):
		if node is EnemyShooter:
			node.enabled = false
			node.stop()
		elif node is Hurtbox:
			node.set_deferred("monitoring", false)
			node.set_deferred("monitorable", false)

## 連鎖爆発の範囲。area が空なら、持ち主の子の Sprite2D の見た目を全部囲む範囲
func _area_of(body : Node2D) -> Rect2:
	if area.has_area():
		return area
	var rect := Rect2()
	var first := true
	for child in body.get_children():
		if child is Sprite2D:
			var r : Rect2 = child.get_rect()
			r = Rect2(child.position + r.position * child.scale, r.size * child.scale)
			rect = r if first else rect.merge(r)
			first = false
	return rect if not first else Rect2(-24, -24, 48, 48)

## node の子の DeathExplosion。なければ null
static func of(node : Node) -> DeathExplosion:
	for child in node.get_children():
		if child is DeathExplosion:
			return child
	return null
