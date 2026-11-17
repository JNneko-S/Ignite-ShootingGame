extends Node
class_name AttackAnimation
## 撃つときだけ、絵のコマを進める部品(ハッチが開く・砲口が出るなど)。敵の子に置く。
## 親の下の EnemyShooter が撃つ(fired)と、Sprites のコマを最後のコマまで進めて「開く」。
## 撃ち終わって Hold Time たつと、最初のコマまで戻して「閉じる」。
## ジェットの噴射のように、いつも動かしておきたいコマは、ここに入れずに AnimationPlayer でループさせる。

## コマを進める絵(Sprite2D。hframes で横に並んだコマを使う)
@export var sprites : Array[Sprite2D] = []
## 1コマ進める(戻す)のにかける秒数
@export var frame_time : float = 0.06
## 最後に撃ってから、閉じはじめるまでの秒数
@export var hold_time : float = 0.9

var _progress : float = 0.0 # 0 = 閉じている、1 = 開ききっている
var _hold : float = 0.0

func _ready() -> void:
	_connect_shooters.call_deferred()
	_apply()

func _connect_shooters() -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	for node in owner_node.find_children("*", "", true, false):
		if node is EnemyShooter and not node.fired.is_connected(_on_fired):
			node.fired.connect(_on_fired)

func _on_fired() -> void:
	_hold = hold_time

func _process(delta : float) -> void:
	var frames := _frame_count()
	if frames <= 1:
		return
	var speed := delta / maxf(frame_time * (frames - 1), 0.001)
	if _hold > 0.0:
		_hold -= delta
		_progress = minf(_progress + speed, 1.0)
	else:
		_progress = maxf(_progress - speed, 0.0)
	_apply()

func _frame_count() -> int:
	var most := 1
	for sprite in sprites:
		if is_instance_valid(sprite):
			most = maxi(most, sprite.hframes * sprite.vframes)
	return most

func _apply() -> void:
	for sprite in sprites:
		if is_instance_valid(sprite):
			var last := sprite.hframes * sprite.vframes - 1
			sprite.frame = clampi(roundi(_progress * last), 0, last)
