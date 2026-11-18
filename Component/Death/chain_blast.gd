extends Node
class_name ChainBlast
## 倒れたときに誘爆して、まわりの敵を巻き込む部品(ステージ3の装甲爆撃機。積んだ爆弾が誘爆する)。敵(Enemy)の子に置く。
##   ・倒れると、少しして大きな爆発が起き、Radius の中の敵に Damage を与える
##   ・巻き込まれて倒れた敵にもこの部品があれば、また誘爆する(連鎖する)
##   ・ボス・中ボス(BossPhaseController や PartsDefeat を持つ敵)は巻き込まない

## 巻き込む範囲(px)と、与えるダメージ
@export var radius : float = 110.0
@export var damage : int = 600
## 倒れてから爆発するまでの時間(秒)
@export var delay : float = 0.18
## 爆発の大きさ
@export var blast_scale : float = 2.2

var _enemy : Enemy

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("ChainBlast: 親が Enemy ではありません")
		return
	_enemy.died.connect(_on_died)

func _on_died(_e : Enemy) -> void:
	var tree := get_tree()
	var at := _enemy.global_position
	await tree.create_timer(delay, false).timeout
	Explosion.spawn(tree, Explosion.EXPLOSIVE, at, blast_scale)
	Explosion.spawn(tree, Explosion.WAVE, at, blast_scale * 0.7)
	Explosion.burst(tree, at, 6, radius * 0.6, 0.9, 0.02)
	var camera := StageCamera.of(_enemy) if is_instance_valid(_enemy) else null
	if camera:
		camera.shake(5.0, 0.3)
	for node in tree.get_nodes_in_group("enemy"):
		var other := node as Enemy
		if other == null or other == _enemy or not is_instance_valid(other) or other.hp_component == null:
			continue
		if other.hp_component.hp <= 0 or other.global_position.distance_to(at) > radius:
			continue
		if _is_big(other):
			continue
		other.hp_component.apply_damage(damage)

## ボス・中ボスか(巻き込まない)
func _is_big(enemy : Enemy) -> bool:
	for child in enemy.get_children():
		if child is BossPhaseController or child is PartsDefeat or child is TrainBossMover:
			return true
	return enemy.is_in_group("stage_boss") or enemy.is_in_group("stage_midboss")
