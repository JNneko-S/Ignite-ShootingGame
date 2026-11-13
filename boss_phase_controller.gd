extends Node
class_name BossPhaseController
## ボスのHPを見て、段階(BossPhase)を切り替える。
##
## 置き方は2通り:
##   ・ボスのシーンに、このノードを置いて Phases を設定する(おすすめ)。
##     砲口ごとの弾幕は、各 EnemyShooter の Phases に入れる
##   ・ステージの SpawnEvent の Phases を設定すると、StageRunner が自動で付ける(シーンに置いていないとき)
##
## 段階が変わると: 画面の敵弾を消し(Clear Bullets)、各砲口を その段階の弾幕に切り替え、ボスが光ってから その段階の色になる。
## 砲口の弾幕: EnemyShooter に Phases があれば、その段階のもの。なければ BossPhase の Patterns(全ての砲口に同じもの)

signal phase_started(index : int)

## 段階。HPの多い順(第一形態が最初、Hp Ratio 1.0)に並べる
@export var phases : Array[BossPhase] = []
## false なら、段階が変わっても砲口の弾幕を切り替えない(ボスのステートが、今の段階を見て撃たせるとき)
@export var switch_shooters : bool = true

var _hp : HPComponent
var _index : int = 0

func _ready() -> void:
	if _hp == null:
		var boss := get_parent()
		if boss:
			_hp = boss.get_node_or_null("HPComponent") as HPComponent
		if _hp:
			_hp.hp_changed.connect(_on_hp_changed)

## StageRunner が SpawnEvent の Phases から付けるときに使う(ツリーに入る前に呼ぶ)
func setup(hp : HPComponent, boss_phases : Array[BossPhase]) -> void:
	_hp = hp
	phases = boss_phases
	_hp.hp_changed.connect(_on_hp_changed)

## 最初の段階の弾幕を、砲口に入れる(敵がツリーに入る前に呼ぶと、そのまま撃ち始める)。
## Phases を持つ砲口は、自分で第一形態の弾幕を使うので、何もしない
func apply_first(enemy : Node) -> void:
	if phases.is_empty():
		return
	for shooter in _shooters(enemy):
		if not shooter.has_phases():
			shooter.patterns = phases[0].patterns

## 今の段階(0 = 第一形態)
func current_phase() -> int:
	return _index

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
		# ボスから近い弾ほど先に、光ってはじけて消える(点にはならない)
		EnemyBullet.vanish_all(get_tree(), (get_parent() as Node2D).global_position)
	var boss := get_parent()
	for shooter in (_shooters(boss) if switch_shooters else []):
		if shooter.has_phases():
			shooter.set_phase(index)
		else:
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
