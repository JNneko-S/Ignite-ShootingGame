extends Node
class_name SupportBlast
## 援護の列車(中ボス列車)を倒したとき、その爆発がとなりのボスまで響いて、ボスに大ダメージを与える部品。
## 援護の列車(Enemy)の子に置く。
##   1. 援護の列車が倒れると、いつもの大爆発(DeathExplosion)が起きる
##   2. 大爆発が終わるころ、爆発の波が線路を横切って、ボスへ向かって走る
##   3. 波がボスに届くと、ボスの見えているところが爆発し、ボスの HP が Boss Damage Ratio の割合だけ減る
## 走り去って消えたとき(倒していないとき)は、何も起きない。

## ボスの HP の最大値に対する、与えるダメージの割合(0.1 なら、1編成でボスのゲージが 1割減る)
@export_range(0.0, 1.0, 0.01) var boss_damage_ratio : float = 0.1
## 倒れてから、波が走り出すまでの時間(秒)。負なら、DeathExplosion の Duration に合わせる
@export var wave_delay : float = -1.0
## 波がボスまで走る時間(秒)
@export var wave_time : float = 0.45
## ボスのグループ(StageRunner が付ける「stage_ + タグ」)
@export var boss_group : StringName = &"stage_boss"
## 波がボスに届いたときに鳴らす音。空なら鳴らさない
@export var hit_sound : AudioStream

var _enemy : Enemy

func _ready() -> void:
	if _exclude != null:
		return # シーンの直下で波を走らせる係
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("SupportBlast: 親が Enemy ではありません")
		return
	_enemy.died.connect(_on_died)

func _on_died(_e : Enemy) -> void:
	var tree := get_tree()
	var from := _enemy.global_position
	var view := CameraView.visible_rect(_enemy)
	from.y = view.get_center().y # 波は、画面の真ん中の高さを走る
	var delay := wave_delay
	if delay < 0.0:
		var death := DeathExplosion.of(_enemy)
		delay = death.duration if death else 1.0
	# 倒れた列車は消えるので、この先は、シーンの直下に置いた別の SupportBlast で進める
	var runner := SupportBlast.new()
	runner.boss_damage_ratio = boss_damage_ratio
	runner.wave_time = wave_time
	runner.boss_group = boss_group
	runner.hit_sound = hit_sound
	runner._exclude = _enemy
	tree.current_scene.add_child(runner)
	runner._run_wave(tree, from, delay)

## 倒れた列車(ボスとして探さない)。シーンの直下で波を走らせるときに使う
var _exclude : Node = null

func _run_wave(tree : SceneTree, from : Vector2, delay : float) -> void:
	await tree.create_timer(delay, false).timeout
	var boss := _find_boss(tree)
	if boss == null:
		queue_free()
		return
	var to := Vector2(boss.global_position.x, from.y)
	# 爆発の波: 倒れた列車から、ボスへ向かって爆発が並んで走る
	var steps := 7
	for i in steps:
		var at := from.lerp(to, float(i + 1) / steps)
		Explosion.spawn(tree, Explosion.EXPLOSIVE, at, 1.1 + 0.15 * i)
		Explosion.burst(tree, at, 3, 26.0, 0.7, 0.02)
		await tree.create_timer(wave_time / steps, false).timeout
	if is_instance_valid(boss) and boss.hp_component and boss.hp_component.hp > 0:
		_hit_boss(tree, boss, to)
	queue_free()

## 波がボスに届いた: ボスの見えているところが爆発して、HP が減る
func _hit_boss(tree : SceneTree, boss : Enemy, at : Vector2) -> void:
	var camera := StageCamera.of(boss)
	if camera:
		camera.shake(12.0, 0.6)
	if hit_sound:
		var player := AudioStreamPlayer.new()
		player.stream = hit_sound
		tree.current_scene.add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
	Explosion.spawn(tree, Explosion.WAVE, at, 2.4)
	Explosion.spawn(tree, Explosion.EXPLOSIVE, at, 3.0)
	var view := CameraView.visible_rect(boss)
	for i in 6:
		var y := randf_range(view.position.y + 40.0, view.end.y - 80.0)
		Explosion.spawn(tree, Explosion.EXPLOSIVE, Vector2(at.x + randf_range(-30.0, 30.0), y), randf_range(1.4, 2.2))
	SpriteShake.shake(boss, 10.0)
	var flash := boss.create_tween()
	var after := boss.modulate
	flash.tween_property(boss, "modulate", Color(2.5, 1.8, 1.6), 0.06)
	flash.tween_property(boss, "modulate", after, 0.4)
	var amount := roundi(boss.hp_component.max_hp * boss_damage_ratio)
	var parts : PartsDefeat = null
	for child in boss.get_children():
		if child is PartsDefeat:
			parts = child
	if parts:
		parts.add_external_damage(amount)
	else:
		boss.hp_component.apply_damage(mini(amount, boss.hp_component.hp))

func _find_boss(tree : SceneTree) -> Enemy:
	for node in tree.get_nodes_in_group(boss_group):
		if node is Enemy and node != _enemy and node != _exclude and is_instance_valid(node):
			return node
	return null
