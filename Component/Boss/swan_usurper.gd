extends Node
class_name SwanUsurper
## (ANOTHER)3面ボスの追加ギミック。ブラックスワン -改- の子に置く。
## -改- が第三形態に入ろうとすると、ブラックスワン -亜- が割り込む:
##   1. -改- は撃つのも動くのもやめ、弾が当たらなくなる(画面の弾は消える)
##   2. -亜- が呼ばれる(BossShadowRush で、大きな影が通り過ぎてから、上から突っ込んでくる)
##   3. 影が通り過ぎたころ、画面の上の外から光線が何本も -改- に刺さる
##   4. -改- が連鎖して爆発し、-亜- が着くのと同時に大爆発して消える(倒した扱いにはしない: ステージはクリアしない)
##   5. そこから -亜- との戦闘(-亜- がこのステージの最後のボス。倒すとクリア)

## この段階(0 から)に入ろうとしたら割り込む
@export var trigger_phase : int = 2
## 割り込んでくるボスのシーン(-亜- は -改- を元にしたシーンなので、preload すると読み込みが循環する。使うときに読む)
@export_file("*.tscn") var usurper_scene_path : String = "res://GameScene/Enemy/Sky/blackswan_a.tscn"
@export var usurper_name : String = "ブラックスワン -亜-"
@export var usurper_thresholds : Array[float] = [0.66, 0.33]
## 割り込みが始まってから、光線が刺さるまで / -改- が大爆発するまでの時間(秒)。
## -亜- の登場(影 0.3 + 1.0 秒、待ち 0.35 秒、突っ込み 1.1 秒)に合わせる
@export var shot_time : float = 1.4
@export var blast_time : float = 2.75
## 光線の数
@export var beams : int = 6

var _boss : Enemy
var _done : bool = false

func _ready() -> void:
	_boss = get_parent() as Enemy
	if _boss == null or not HazardRank.active:
		return
	_connect.call_deferred()

func _connect() -> void:
	for child in _boss.get_children():
		if child is BossPhaseController:
			child.phase_started.connect(_on_phase_started)

func _on_phase_started(index : int) -> void:
	if _done or index < trigger_phase or not is_instance_valid(_boss):
		return
	_done = true
	_run()

func _run() -> void:
	var tree := get_tree()
	# 1. -改- を止める
	_freeze()
	EnemyBullet.vanish_all(tree, _boss.global_position)
	# 2. -亜- を呼ぶ
	var runner := tree.get_first_node_in_group("stage_runner") as StageRunner
	var usurper_scene := load(usurper_scene_path) as PackedScene if usurper_scene_path != "" else null
	if runner and usurper_scene:
		var event := SpawnEvent.new()
		event.enemy_scene = usurper_scene
		event.tag = "boss"
		event.is_boss = true
		event.boss_name = usurper_name
		event.boss_phase_thresholds = usurper_thresholds
		event.boss_time_bonus = true
		runner.spawn(event, 0)
	# 3. 光線が刺さる
	await tree.create_timer(shot_time, false).timeout
	if not is_instance_valid(_boss):
		return
	var view := CameraView.visible_rect(_boss)
	for i in beams:
		var from := Vector2(view.position.x + view.size.x * randf_range(0.15, 0.85), view.position.y - 20.0)
		var to := _boss.global_position + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		_beam(from, to)
		Explosion.spawn(tree, Explosion.EXPLOSIVE, to, 0.9)
		await tree.create_timer(0.07, false).timeout
	var camera := StageCamera.of(_boss)
	if camera:
		camera.shake(5.0, 0.4)
	# 4. 連鎖して爆発してから、大爆発して消える
	var left := blast_time - shot_time - beams * 0.07
	var t := 0.0
	while t < left and is_instance_valid(_boss):
		var at := _boss.global_position + Vector2(randf_range(-90, 90), randf_range(-50, 50))
		Explosion.spawn(tree, Explosion.EXPLOSIVE, at, randf_range(0.8, 1.4))
		await tree.create_timer(0.12, false).timeout
		t += 0.12
	if not is_instance_valid(_boss):
		return
	var center := _boss.global_position
	for i in 6:
		Explosion.spawn(tree, Explosion.EXPLOSIVE, center + Vector2.from_angle(TAU * i / 6.0) * 50.0, 2.0)
	Explosion.spawn(tree, Explosion.WAVE, center, 3.0)
	if camera:
		camera.shake(12.0, 0.8)
	HitStop.flash(tree)
	# 倒した扱いにしない(died を出さない)ので、ステージはクリアしない。消すだけ
	_boss.remove_from_group("enemy")
	_boss.queue_free()

## 撃つのも動くのもやめて、弾が当たらなくなる
func _freeze() -> void:
	_boss.set_meta(&"hold_position", true)
	for node in _boss.find_children("*", "", true, false):
		if node is EnemyShooter:
			node.stop()
			node.enabled = false
		elif node is CollisionShape2D or node is CollisionPolygon2D:
			node.set_deferred("disabled", true)
		elif node.name in ["StateMachine", "FighterMover", "AfterburnerDive", "BossPhaseController"]:
			node.process_mode = Node.PROCESS_MODE_DISABLED

## 画面の上の外から刺さる光線(見た目だけ)
func _beam(from : Vector2, to : Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 6.0
	line.default_color = Color(1.0, 0.35, 0.3, 0.95)
	line.z_as_relative = false
	line.z_index = 6
	get_tree().current_scene.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "width", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(line.queue_free)
