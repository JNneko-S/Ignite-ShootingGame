extends Node
class_name GuardFinale
## ラスボスの前の中ボス(中枢防衛艦)が倒されたときの演出。敵(Enemy)の子に置く。
##   1. 長めに、機体のあちこちで爆発が続く(画面が揺れ続ける)
##   2. 画面の真ん中の下(中枢のコア)から、巨大なレーザーが立ち上って、機体を貫く
##   3. 撃ち抜かれた機体は、バババッと爆発を続けながら、傾いて小さくなり、地上へ墜ちていく。最後に地面で大爆発する
## 敵の Keep After Death をオンにして、倒れたあとも姿を残す(爆発のあいだも、当たり判定は消える)。

## 爆発が続く時間(秒)と、爆発の間隔(秒)
@export var blast_time : float = 2.2
@export var blast_interval : float = 0.07
## レーザーが立ち上る時間・いちばん太いときの幅(px)・消えるまでの時間(秒)
@export var laser_rise_time : float = 0.35
@export var laser_width : float = 90.0
@export var laser_hold_time : float = 0.8
## 墜ちる時間(秒)・墜ちるあいだに流れる距離(px)・傾く角度(度)・最後の大きさ(地上の遠さ)・爆発の間隔(秒)
@export var fall_time : float = 2.4
@export var fall_drift : Vector2 = Vector2(30.0, 90.0)
@export var fall_tilt : float = 24.0
@export var fall_end_scale : float = 0.3
@export var fall_blast_interval : float = 0.045
## レーザーの色(外側)
@export var laser_color : Color = Color(1.0, 0.32, 0.12)
## 倒されたときに支給するアイテム(ラスボスの前の補給。全ての難易度)。
## 回復(イグナイトのレベルが 3 より低ければ 3 まで戻す)と、子機2つ。どちらも自機へ吸い寄せられる
@export var supply_items : Array[PackedScene] = [
	preload("res://GameScene/Item/power_up_heal.tscn"),
	preload("res://GameScene/Item/power_up_option_pair.tscn"),
]

var _enemy : Enemy
var _visual : Node2D
var _area : Rect2 = Rect2(-150, -90, 300, 180)

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.keep_after_death = true
	var death := DeathExplosion.of(_enemy)
	if death:
		death.fade_out_body = false # 大爆発のあとも、姿を残す(このあとレーザーで吹き飛ぶ)
		if death.area.size != Vector2.ZERO:
			_area = death.area
	_visual = _enemy.get_node_or_null("VisualRoot") as Node2D
	_enemy.died.connect(_on_died)

func _on_died(_e : Enemy) -> void:
	var tree := get_tree()
	# 1. 爆発が続く
	var camera := StageCamera.of(_enemy)
	var left := blast_time
	while left > 0.0 and is_instance_valid(_enemy):
		_blast(Explosion.EXPLOSIVE if randf() < 0.35 else Explosion.ZAKO, randf_range(0.8, 1.6))
		if camera:
			camera.shake(4.0, 0.12)
		await tree.create_timer(blast_interval, false).timeout
		left -= blast_interval
	if not is_instance_valid(_enemy):
		return
	# 2. コアからレーザー
	var laser := CoreLaser.new()
	laser.color = laser_color
	laser.z_index = 30
	tree.current_scene.add_child(laser)
	var view := CameraView.visible_rect(_enemy)
	laser.global_position = Vector2(_enemy.global_position.x, view.end.y + 20.0)
	laser.length = laser.global_position.y - view.position.y + 40.0
	var rise := laser.create_tween()
	rise.tween_property(laser, "width", laser_width, laser_rise_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tree.create_timer(laser_rise_time * 0.6, false).timeout
	ScreenFlash.play(tree, 1.0)
	HitStop.apply(tree, 0.12)
	_supply()
	if camera:
		camera.shake(12.0, 0.8)
	for i in 6:
		_blast(Explosion.WAVE if i == 0 else Explosion.EXPLOSIVE, 2.2 if i == 0 else 1.4)
	# 3. 墜ちる(レーザーは少し残ってから細くなって消える)
	var fade := laser.create_tween()
	fade.tween_interval(laser_hold_time)
	fade.tween_property(laser, "width", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_callback(laser.queue_free)
	await _fall()
	if is_instance_valid(_enemy):
		_enemy.queue_free()

## バババッと爆発を続けながら、傾いて小さくなって(遠くの地上へ)墜ちる。最後に地面で大爆発する
func _fall() -> void:
	var start_pos := _enemy.global_position
	var start_scale := _enemy.scale
	var camera := StageCamera.of(_enemy)
	var time := 0.0
	var next_blast := 0.0
	while time < fall_time and is_instance_valid(_enemy):
		var delta := get_process_delta_time()
		time += delta
		var k := time / fall_time
		var ease_k := k * k # だんだん速く墜ちる
		_enemy.global_position = start_pos + fall_drift * ease_k
		_enemy.scale = start_scale * lerpf(1.0, fall_end_scale, ease_k)
		_enemy.rotation_degrees = fall_tilt * ease_k
		if _visual:
			_visual.modulate = Color.WHITE.lerp(Color(0.35, 0.25, 0.22), k)
		next_blast -= delta
		if next_blast <= 0.0:
			next_blast = fall_blast_interval
			_blast(Explosion.EXPLOSIVE if randf() < 0.3 else Explosion.ZAKO, randf_range(0.8, 1.5) * _enemy.scale.x)
			if camera:
				camera.shake(3.0, 0.08)
		await get_tree().process_frame
	if not is_instance_valid(_enemy):
		return
	# 地面に墜ちた: 大爆発
	Explosion.spawn(get_tree(), Explosion.WAVE, _enemy.global_position, 2.0)
	for i in 8:
		_blast(Explosion.EXPLOSIVE, 1.2)
	if camera:
		camera.shake(10.0, 0.6)
	ScreenFlash.play(get_tree(), 0.5)
	_enemy.visible = false
	await get_tree().create_timer(0.6, false).timeout

func _blast(scene : PackedScene, scale : float) -> void:
	if not is_instance_valid(_enemy):
		return
	var local := Vector2(randf_range(_area.position.x, _area.end.x), randf_range(_area.position.y, _area.end.y))
	Explosion.spawn(get_tree(), scene, _enemy.to_global(local), scale)

## 中枢のコアから立ち上るレーザー(見た目だけ。下から上へまっすぐ伸びる)
class CoreLaser extends Node2D:
	var color : Color = Color(1.0, 0.32, 0.12)
	var length : float = 800.0
	var width : float = 0.0:
		set(value):
			width = value
			queue_redraw()
	var _time : float = 0.0

	func _process(delta : float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if width <= 0.5:
			return
		var wobble := 1.0 + sin(_time * 40.0) * 0.06
		var w := width * wobble
		# 外側の光 → 内側の光 → 白い芯
		draw_rect(Rect2(-w * 0.9, -length, w * 1.8, length), Color(color, 0.25))
		draw_rect(Rect2(-w * 0.5, -length, w, length), Color(color, 0.7))
		draw_rect(Rect2(-w * 0.22, -length, w * 0.44, length), Color(1.0, 0.95, 0.85, 1.0))
		# 根元(コア)の光の玉
		draw_circle(Vector2.ZERO, w * 0.9, Color(color, 0.5))
		draw_circle(Vector2.ZERO, w * 0.5, Color(1.0, 0.95, 0.85, 0.95))

## ラスボスの前の補給: 機体のそばに、回復と子機2つのアイテムを出す(画面の中に寄せる)
func _supply() -> void:
	var view := CameraView.visible_rect(_enemy)
	var at := _enemy.global_position
	at = Vector2(clampf(at.x, view.position.x + 80.0, view.end.x - 80.0),
		clampf(at.y, view.position.y + 100.0, view.position.y + view.size.y * 0.45))
	var i := 0
	for scene in supply_items:
		if scene == null:
			continue
		var item := scene.instantiate() as Node2D
		get_tree().current_scene.add_child.call_deferred(item)
		item.set_deferred(&"global_position", at + Vector2((i - (supply_items.size() - 1) * 0.5) * 48.0, 0.0))
		i += 1
