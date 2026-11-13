extends Node
class_name ShadowFlyby
## ボスの登場の前ぶれ。ボス(Enemy)の子に置く。
## ボスが出現した瞬間に、はるか上空を飛ぶ戦闘機の「影」が、V字の編隊で画面の下から上へ追い越していく。
## そのあとにボスが飛んでくるように、ボスの移動パターンの最初に、待つ区間を入れておく(BlackSwan は 1.8 秒)。
##
## 影は、絵(Texture)を黒くして半透明にしたもの。地面・建物・地上の敵の上、自機と空の敵の下に描く。
## 編隊は、先頭が1機で、後ろへ行くほど左右に広がる(Count は奇数にすると左右対称になる)。

## 影にする戦闘機の絵。空なら何も出ない。絵は機首が下向きの前提(上へ飛ぶので、上下を逆にして出す)
@export var texture : Texture2D
## 絵が横に何コマ並んでいるか(1コマ目を使う)
@export var hframes : int = 1
## 影の大きさの倍率。上空を飛んでいるので、実物より大きめにすると高さが出る
@export var shadow_scale : float = 2.0
## 影の色(黒の半透明)
@export var shadow_color : Color = Color(0.0, 0.0, 0.05, 0.42)

@export_group("編隊")
## 1つの編隊の機数
@export var count : int = 5
## 隣の機との、横と縦の間隔(px)。縦は、後ろの機ほど下にずれる量
@export var spacing : Vector2 = Vector2(92, 64)
## 編隊の数と、次の編隊が来るまでの間隔(秒)
@export var waves : int = 2
@export var wave_interval : float = 0.5
## 2つ目以降の編隊を、横へずらす量(px)。1つおきに左右が逆になる
@export var wave_offset_x : float = 46.0
## 編隊の真ん中の横位置。画面の左端 0 〜 右端 1
@export_range(0.0, 1.0, 0.05) var center_ratio : float = 0.5

@export_group("動き")
## ボスが出現してから、最初の編隊が来るまでの時間(秒)
@export var delay : float = 0.15
## 画面の下から上まで通り抜ける時間(秒)。小さいほど速い
@export var pass_time : float = 1.0
## 通り抜けるあいだの横への流れ(px)。0 ならまっすぐ上へ
@export var drift_x : float = 0.0
## 通り過ぎるときの効果音(AudioStreamPlayer)。空なら鳴らさない
@export var sound : AudioStreamPlayer

func _ready() -> void:
	if texture == null or count <= 0 or waves <= 0:
		return
	_run.call_deferred()

func _run() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if delay > 0.0:
		await tree.create_timer(delay, false).timeout
	for wave in waves:
		if not is_inside_tree():
			return
		var side := 0.0 if wave == 0 else (1.0 if wave % 2 == 1 else -1.0)
		_spawn_wave(side * wave_offset_x)
		SoundManager.play(sound, 1.0 + 0.08 * wave)
		if wave < waves - 1 and wave_interval > 0.0:
			await tree.create_timer(wave_interval, false).timeout

## V字の編隊を1つ出す。ボスが先に消えても最後まで飛ぶように、ステージの直下に出して、ステージの Tween で動かす
func _spawn_wave(offset_x : float) -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	if scene == null:
		return
	var view := CameraView.visible_rect(scene)
	var size := texture.get_size() * shadow_scale
	var center_x := view.position.x + view.size.x * center_ratio + offset_x
	var depth := spacing.y * float(count / 2) # 編隊の縦の長さ
	var start_y := view.end.y + size.y
	var end_y := view.position.y - size.y - depth
	for i in count:
		# 0 が先頭。1, 2 がその左右、3, 4 がさらに外側 …
		var rank := (i + 1) / 2
		var side := 0.0 if i == 0 else (-1.0 if i % 2 == 1 else 1.0)
		var shadow := Sprite2D.new()
		shadow.texture = texture
		shadow.hframes = maxi(hframes, 1)
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.scale = Vector2.ONE * shadow_scale
		shadow.rotation = PI # 機首を上へ
		shadow.modulate = shadow_color
		shadow.z_index = 0 # あとから足すので、地面・建物・地上の敵(0)の上、自機(1)・空の敵(2)の下
		scene.add_child(shadow)
		var x := center_x + side * spacing.x * rank
		var y := spacing.y * rank
		shadow.global_position = Vector2(x, start_y + y)
		var tween := scene.create_tween()
		tween.tween_property(shadow, "global_position", Vector2(x + drift_x, end_y + y), pass_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(shadow.queue_free)
