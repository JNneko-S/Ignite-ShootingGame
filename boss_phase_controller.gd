extends Node
class_name BossPhaseController
## ボスのHPを見て、BossPhase の段階ごとに弾幕を切り替える。
## StageRunner が、Phases を設定した SpawnEvent の敵に、子ノードとして自動で付ける。

signal phase_started(index : int)

var phases : Array[BossPhase] = []
var _hp : HPComponent
var _index : int = 0

func setup(hp : HPComponent, boss_phases : Array[BossPhase]) -> void:
	_hp = hp
	phases = boss_phases
	_hp.hp_changed.connect(_on_hp_changed)

## 最初の段階の弾幕を、砲口に入れる(敵がツリーに入る前に呼ぶと、そのまま撃ち始める)
func apply_first(enemy : Node) -> void:
	if phases.is_empty():
		return
	for shooter in _shooters(enemy):
		shooter.patterns = phases[0].patterns

func _on_hp_changed() -> void:
	if _hp.max_hp <= 0:
		return
	var ratio := float(_hp.hp) / _hp.max_hp
	# HPが一気に減ったときは、飛ばした段階も含めて、当てはまる最後の段階まで進める
	var next := _index
	while next + 1 < phases.size() and ratio <= phases[next + 1].hp_ratio:
		next += 1
	if next != _index and _hp.hp > 0:
		_start_phase(next)

func _start_phase(index : int) -> void:
	_index = index
	var phase := phases[index]
	if phase.clear_bullets:
		get_tree().call_group("enemy_bullet", "queue_free")
	var boss := owner if owner else get_parent()
	for shooter in _shooters(boss):
		shooter.set_patterns(phase.patterns)
	# 白く光ってから、この段階の色になる
	var tween := create_tween()
	tween.tween_property(boss, "modulate", Color(2.0, 2.0, 2.0), 0.08)
	tween.tween_property(boss, "modulate", phase.boss_modulate, 0.4)
	phase_started.emit(index)

func _shooters(enemy : Node) -> Array[EnemyShooter]:
	var result : Array[EnemyShooter] = []
	for node in enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			result.append(node)
	return result
