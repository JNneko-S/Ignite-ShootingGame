extends HPComponent
class_name SquadHP
## 何機かでまとめて出てくるボス・中ボス(ブラックスワンズなど)の、全機の HP の合計。StageRunner が作る。
## ボスのゲージ(BossGauge)は、1機ではなくこの合計につなぐ。全機を倒すと 0 になって、ゲージが退場する。
## 全機がいなくなったら(倒された・画面の外へ消えた)、自分も消える。

var _members : Array[HPComponent] = []
var _gone : int = 0

func _init() -> void:
	max_hp = 0 # 仲間を足すまでは空(hp の setter は呼ばない: 0 にすると「倒れた」ことになるので)

## 仲間を1機足す(ツリーに入ったあとに呼ぶ)
func add_member(enemy : Enemy) -> void:
	var member := enemy.hp_component
	if member == null:
		return
	_members.append(member)
	max_hp += member.max_hp
	member.hp_changed.connect(_recount)
	enemy.tree_exited.connect(_on_member_gone)
	_recount()

## 全機の残りの HP を数え直す
func _recount() -> void:
	var total := 0
	for member in _members:
		if is_instance_valid(member):
			total += maxi(member.hp, 0)
	hp = total

func _on_member_gone() -> void:
	if not is_inside_tree():
		return # ステージごと消えるところ
	_gone += 1
	_recount()
	if _gone >= _members.size():
		# 全機いなくなった: ゲージの退場を待ってから消える
		get_tree().create_timer(2.0, false).timeout.connect(queue_free)
