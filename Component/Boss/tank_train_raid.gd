extends Node
class_name TankTrainRaid
## (ANOTHER)1面ボスの戦車の追加ギミック。ボス(Enemy)の子に置く。
## 第二形態(Active From Phase)から、Interval 秒ごとに次を繰り返す:
##   1. 戦車から遠いほうの線路に、画面の下から列車が走ってきて、戦車の横で並走する
##      (列車が来ているあいだ、戦車はその線路の側へ回り込まない: TankMover.blocked_side)
##   2. 戦車が砲弾を撃って列車に当てる
##   3. 車両が先頭から順に爆発し、それぞれから花火の弾幕(Burst Pattern)が出る
##   4. 残骸は画面の上へ流れて消える
## 列車は飾り(当たり判定なし)。弾幕だけが危ない。

## この段階(0 = 第一形態)から列車が来る
@export var active_from_phase : int = 1
## 列車が来る間隔(秒)と、段階に入ってから最初の列車までの時間(秒)
@export var interval : float = 14.0
@export var first_delay : float = 2.5
## 車両の数
@export var car_count : int = 4
## 線路(2本のレールの真ん中)の位置。背景のスプライト(Ground Path)の絵の、左の端からの px。
## ボス戦の地面「Loop this at the end」(幅 240)の線路は、左から 46.5 / 67.5 / 165.5 / 186.5。
## 外側の2本を使う(内側の2本は、戦車の車体と重なる)。このうち戦車から遠いほうを使う
## (背景を繰り返すとき、絵の基準が真ん中から左上に変わるので、絵の px で持って毎回換算する)
@export var rail_texture_x : Array[float] = [46.5, 186.5]
## 背景のスプライト(線路の位置と、車両の大きさをここから決める。横揺れにも付いていく)
@export var ground_path : NodePath = ^"Scroller/LoopThisAtTheEnd"
## 車両の絵の、車体の真ん中を線路の真ん中に合わせるずれ(絵の px。Small Train の絵は右に影があるので 3.5)
@export var car_offset : Vector2 = Vector2(3.5, 0.0)
## 爆発した車両から出る弾幕
@export var burst_pattern : ShotPattern = preload("res://Resources/ShotPatterns/Another/a1_raid_firework.tres")
## 走ってきて並走するまでの時間、並走している時間、砲弾が飛ぶ時間、車両が順に爆発する間隔(秒)
@export var arrive_time : float = 1.6
@export var run_time : float = 1.0
@export var shell_time : float = 0.35
@export var chain_interval : float = 0.22

const LOCO := preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn00_Strip2.png")
## 車両の絵(壊れる前, 壊れたあと)
const WAGONS := [
	[preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn21.png"), preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn20.png")],
	[preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn30.png"), preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn31.png")],
	[preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn40.png"), preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn41.png")],
	[preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn50.png"), preload("res://Assets/Full Shmup Asset Pack/Backgrounds/Train Stage/Small Train/SmallTrain_Wgn51.png")],
]

var _boss : Enemy
var _running : bool = false

func _ready() -> void:
	_boss = get_parent() as Enemy
	if _boss == null or not HazardRank.active:
		set_process(false)
		return
	_loop.call_deferred()

func _phase() -> int:
	for child in _boss.get_children():
		if child is BossPhaseController:
			return child.current_phase()
	return 0

func _alive() -> bool:
	return is_instance_valid(_boss) and _boss.is_inside_tree() and not _boss._is_dead

func _wait(seconds : float) -> void:
	if _alive():
		await get_tree().create_timer(seconds, false).timeout

func _loop() -> void:
	# 段階に入るまで待つ
	while _alive() and _phase() < active_from_phase:
		await _wait(0.25)
	await _wait(first_delay)
	while _alive():
		await _raid()
		await _wait(interval)

func _mover() -> TankMover:
	for child in _boss.get_children():
		if child is TankMover:
			return child
	return null

## 線路の x(ワールド)と、車両の大きさ。背景が見つからなければ、画面の左右の端寄り
func _lanes() -> Array:
	var ground := get_tree().current_scene.get_node_or_null(ground_path) as Node2D
	var view := CameraView.visible_rect(_boss)
	var xs : Array[float] = []
	if ground:
		for tx in rail_texture_x:
			xs.append(ground.to_global(Vector2(tex_to_local(ground, tx), 0.0)).x)
	else:
		xs = [view.position.x + view.size.x * 0.18, view.position.x + view.size.x * 0.82]
	return xs

func _ground_scale() -> float:
	var ground := get_tree().current_scene.get_node_or_null(ground_path) as Node2D
	return absf(ground.global_scale.x) if ground else 2.0

func _raid() -> void:
	if not _alive():
		return
	var lanes := _lanes()
	if lanes.is_empty():
		return
	# 戦車から遠いほうの線路
	var lane_index := 0
	for i in lanes.size():
		if absf(lanes[i] - _boss.global_position.x) > absf(lanes[lane_index] - _boss.global_position.x):
			lane_index = i
	var lane : float = lanes[lane_index]
	var mover := _mover()
	if mover:
		mover.blocked_side = signf(lane - mover.home_x())
	var view := CameraView.visible_rect(_boss)
	var s := _ground_scale()
	var car_h := 58.0 * s + 2.0 * s
	# 列車を組み立てる(先頭が上)
	var train := RailTrain.new()
	train.ground = get_tree().current_scene.get_node_or_null(ground_path) as Node2D
	train.texture_x = rail_texture_x[lane_index] if lane_index < rail_texture_x.size() else 0.0
	train.z_as_relative = false
	train.z_index = 0 # 地面より手前、敵や弾より奥
	var cars : Array[Sprite2D] = []
	for i in car_count:
		var car := Sprite2D.new()
		car.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if i == 0:
			car.texture = LOCO
			car.hframes = 2
		else:
			var pair : Array = WAGONS[(i - 1) % WAGONS.size()]
			car.texture = pair[0]
			car.set_meta("broken", pair[1])
		car.scale = Vector2(s, s)
		car.offset = car_offset
		car.position = Vector2(0.0, i * car_h)
		train.add_child(car)
		cars.append(car)
	get_tree().current_scene.add_child(train)
	var length := car_count * car_h
	train.global_position = Vector2(lane, view.end.y + 40.0)
	# 1. 走ってきて、戦車の横で並走する(列車の真ん中が戦車の高さ)
	var beside := _boss.global_position.y - length * 0.5 + car_h * 0.5
	var run := train.create_tween()
	run.tween_property(train, "global_position:y", beside, arrive_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await run.finished
	await _wait(run_time)
	if not _alive() or not is_instance_valid(train):
		_clear_block(mover)
		if is_instance_valid(train):
			train.queue_free()
		return
	# 2. 戦車が砲弾を撃って、列車の先頭に当てる
	await _fire_shell(_boss.global_position, cars[0].global_position)
	# 3. 先頭から順に爆発して、花火の弾幕を出す
	for car in cars:
		if not is_instance_valid(car):
			continue
		_explode(car, s)
		await _wait(chain_interval)
	# 4. 残骸は画面の上へ流れて消える
	if is_instance_valid(train):
		var leave := train.create_tween()
		leave.tween_property(train, "global_position:y", view.position.y - length - 40.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		leave.parallel().tween_property(train, "modulate:a", 0.35, 1.6)
		leave.tween_callback(train.queue_free)
	_clear_block(mover)

func _clear_block(mover : TankMover) -> void:
	if is_instance_valid(mover):
		mover.blocked_side = 0.0

## 戦車から目標へ飛ぶ砲弾(見た目だけ)
func _fire_shell(from : Vector2, to : Vector2) -> void:
	var shell := ShellFlash.new()
	shell.z_as_relative = false
	shell.z_index = 6
	get_tree().current_scene.add_child(shell)
	shell.global_position = from
	var tween := shell.create_tween()
	tween.tween_property(shell, "global_position", to, shell_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(shell.queue_free)
	await tween.finished

func _explode(car : Sprite2D, s : float) -> void:
	var at := car.global_position
	Explosion.spawn(get_tree(), Explosion.EXPLOSIVE, at, s * 0.9)
	if car.has_meta("broken"):
		car.texture = car.get_meta("broken")
	else:
		car.modulate = Color(0.35, 0.3, 0.3)
	var camera := StageCamera.of(_boss)
	if camera:
		camera.shake(3.0, 0.15)
	if burst_pattern:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var aim := (player.global_position - at).angle() if player else Vector2.DOWN.angle()
		var tuned := DifficultyTuning.tune(burst_pattern, false)
		EnemyShooter.spawn_bullets(tuned, 0, aim, at, get_tree().current_scene, null)

## 砲弾の見た目: 光る玉と、短い尾
class ShellFlash extends Node2D:
	var _last : Vector2 = Vector2.INF
	func _process(_delta : float) -> void:
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.7, 0.25, 0.35))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.95, 0.7))

## 列車: 横の位置は、いつも背景の線路に合わせる(背景の横揺れに付いていく)。縦の位置は tween で動かす
class RailTrain extends Node2D:
	var ground : Node2D
	var texture_x : float = 0.0
	func _process(_delta : float) -> void:
		if is_instance_valid(ground):
			global_position.x = ground.to_global(Vector2(TankTrainRaid.tex_to_local(ground, texture_x), 0.0)).x

## 背景のスプライトの絵の、左の端からの px を、スプライトのローカルの x にする(真ん中基準でも、左上基準でも)
static func tex_to_local(ground : Node2D, tx : float) -> float:
	var sprite := ground as Sprite2D
	if sprite == null or sprite.texture == null:
		return tx
	var width := sprite.region_rect.size.x if sprite.region_enabled else float(sprite.texture.get_width())
	return tx - (width * 0.5 if sprite.centered else 0.0) + sprite.offset.x
