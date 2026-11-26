extends Node
class_name NucleoFinale
## ラスボス(ヌクレオ)の最期。ラスボス(Enemy)の子に置く。終わったら finished を出す(EndingSequence が待つ)。
##   1. 最後の足掻き: 赤く明滅しながら、全身からレーザーを乱射して、ステージを焼き払う(着弾したところが次々に爆発する)
##      レーザーは見た目だけ(自機には当たらない。もう勝負はついている)
##   2. 力尽きて、全身で爆発が起こり続ける
##   3. 傾きながら地面へ墜ちて、激突。さらに巨大な爆発が起こる
## 文字は出さない(演出は光と爆発だけ)。

signal finished

## 乱射の時間(秒)・レーザーの本数・1本が光っている時間(秒)
@export var rage_time : float = 3.4
@export var laser_count : int = 16
@export var laser_life : float = 1.0
## 爆発し続ける時間(秒)と間隔(秒)
@export var burn_time : float = 2.4
@export var burn_interval : float = 0.05
## 墜ちる時間(秒)・流れる距離(px)・傾き(度)・最後の大きさ
@export var crash_time : float = 2.2
@export var crash_drift : Vector2 = Vector2(-20.0, 110.0)
@export var crash_tilt : float = -18.0
@export var crash_end_scale : float = 0.35
## レーザーの色
@export var laser_color : Color = Color(1.0, 0.25, 0.12)

var _enemy : Enemy
var _visual : Node2D
var _area : Rect2 = Rect2(-180, -150, 360, 300)
## 最期の演出が終わったか(finished を出したあとに待ち始めた人が、待ちぼうけにならないように)
var done : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.keep_after_death = true
	var death := DeathExplosion.of(_enemy)
	if death:
		death.fade_out_body = false
		if death.area.size != Vector2.ZERO:
			_area = death.area
	_visual = _enemy.get_node_or_null("VisualRoot") as Node2D
	_enemy.died.connect(_on_died)

func _on_died(_e : Enemy) -> void:
	var tree := get_tree()
	if DebugTools.union_direct:
		# デバッグ(裏ボス Union 戦へすぐ): 最期の演出を短くする
		rage_time = 0.9
		laser_count = 6
		burn_time = 0.5
		crash_time = 1.0
	var camera := StageCamera.of(_enemy)
	# 撃つのは止める(ビームも)
	for node in _enemy.find_children("*", "", true, false):
		if node is BeamShooter:
			node.queue_free()
	# 1. 最後の足掻き
	HitStop.apply(tree, 0.2)
	ScreenFlash.play(tree, 0.6)
	var blink := create_tween().set_loops(int(rage_time / 0.16))
	if _visual:
		blink.tween_property(_visual, "modulate", Color(2.2, 0.6, 0.5), 0.08)
		blink.tween_property(_visual, "modulate", Color(1.0, 0.5, 0.45), 0.08)
	var step := rage_time / float(maxi(laser_count, 1))
	for i in laser_count:
		if not is_instance_valid(_enemy):
			return
		_fire_laser()
		if camera:
			camera.shake(6.0, 0.25)
		await tree.create_timer(step, false).timeout
	blink.kill()
	# 2. 爆発し続ける
	var left := burn_time
	while left > 0.0 and is_instance_valid(_enemy):
		_blast(Explosion.EXPLOSIVE if randf() < 0.4 else Explosion.ZAKO, randf_range(1.0, 2.0))
		if camera:
			camera.shake(5.0, 0.1)
		await tree.create_timer(burn_interval, false).timeout
		left -= burn_interval
	# 3. 墜ちて、激突
	await _crash()
	done = true
	finished.emit()

## レーザーを1本撃つ: 体のどこかから、下のほうのランダムな向きへ伸びて、なぎ払いながら消える。
## 伸びた先(ステージ)が、レーザーに沿って次々に爆発する
func _fire_laser() -> void:
	var laser := RageLaser.new()
	laser.color = laser_color
	laser.z_index = 30
	get_tree().current_scene.add_child(laser)
	var local := Vector2(randf_range(_area.position.x * 0.7, _area.end.x * 0.7), randf_range(-20.0, _area.end.y * 0.6))
	laser.global_position = _enemy.to_global(local)
	var start := deg_to_rad(randf_range(30.0, 150.0))
	var sweep := deg_to_rad(randf_range(-45.0, 45.0))
	laser.angle = start
	var tween := laser.create_tween()
	tween.tween_property(laser, "width", randf_range(14.0, 26.0), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(laser, "angle", start + sweep, laser_life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(laser, "width", 0.0, 0.25)
	tween.tween_callback(laser.queue_free)
	# レーザーが当たったステージが爆発していく
	var tree := get_tree()
	var hits := 7
	for k in hits:
		tree.create_timer(0.1 + laser_life * float(k) / hits, false).timeout.connect(func() -> void:
			if is_instance_valid(laser):
				var at : Vector2 = laser.global_position + Vector2.from_angle(laser.angle) * randf_range(140.0, 520.0)
				Explosion.spawn(tree, Explosion.EXPLOSIVE if randf() < 0.5 else Explosion.ZAKO, at, randf_range(1.2, 2.2)))

## 傾きながら、小さくなって(遠くの地面へ)墜ちる。最後に地面で巨大な爆発
func _crash() -> void:
	var start_pos := _enemy.global_position
	var start_scale := _enemy.scale
	var camera := StageCamera.of(_enemy)
	var time := 0.0
	var next_blast := 0.0
	while time < crash_time and is_instance_valid(_enemy):
		var delta := get_process_delta_time()
		time += delta
		var k := time / crash_time
		var e := k * k
		_enemy.global_position = start_pos + crash_drift * e
		_enemy.scale = start_scale * lerpf(1.0, crash_end_scale, e)
		_enemy.rotation_degrees = crash_tilt * e
		if _visual:
			_visual.modulate = Color(1.0, 0.5, 0.45).lerp(Color(0.3, 0.2, 0.18), k)
		next_blast -= delta
		if next_blast <= 0.0:
			next_blast = 0.04
			_blast(Explosion.EXPLOSIVE if randf() < 0.35 else Explosion.ZAKO, randf_range(1.0, 1.8) * _enemy.scale.x)
			if camera:
				camera.shake(4.0, 0.08)
		await get_tree().process_frame
	if not is_instance_valid(_enemy):
		return
	# 激突
	var at := _enemy.global_position
	HitStop.apply(get_tree(), 0.25)
	ScreenFlash.play(get_tree(), 1.0)
	if camera:
		camera.shake(18.0, 1.4)
	for i in 3:
		Explosion.spawn(get_tree(), Explosion.WAVE, at + Vector2(randf_range(-60, 60), randf_range(-30, 30)), 3.0 - i * 0.6)
	for i in 18:
		Explosion.spawn(get_tree(), Explosion.EXPLOSIVE, at + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 170.0), randf_range(1.4, 2.6))
	_enemy.visible = false
	await get_tree().create_timer(0.4 if rage_time < 1.0 else 1.2, false).timeout

func _blast(scene : PackedScene, scale : float) -> void:
	if not is_instance_valid(_enemy):
		return
	var local := Vector2(randf_range(_area.position.x, _area.end.x), randf_range(_area.position.y, _area.end.y))
	Explosion.spawn(get_tree(), scene, _enemy.to_global(local), scale)

## 足掻きのレーザー(見た目だけ)。angle の向きへまっすぐ伸びる
class RageLaser extends Node2D:
	var color : Color = Color.RED
	var length : float = 1100.0
	var angle : float = 0.0:
		set(value):
			angle = value
			queue_redraw()
	var width : float = 0.0:
		set(value):
			width = value
			queue_redraw()

	func _draw() -> void:
		if width <= 0.5:
			return
		var dir := Vector2.from_angle(angle)
		var normal := dir.orthogonal()
		for layer in [[1.8, Color(color, 0.25)], [1.0, Color(color, 0.75)], [0.4, Color(1.0, 0.95, 0.85, 1.0)]]:
			var w : float = width * layer[0] * 0.5
			var pts := PackedVector2Array([normal * w, dir * length + normal * w, dir * length - normal * w, -normal * w])
			draw_colored_polygon(pts, layer[1])
		draw_circle(Vector2.ZERO, width * 0.9, Color(1.0, 0.9, 0.8, 0.9))
