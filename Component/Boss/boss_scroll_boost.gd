extends Node
class_name BossScrollBoost
## ボス戦のあいだ、背景のスクロールを速くする部品。ボス(Enemy)の子に置く。
##   ・ボスが出現すると、スクロールが Boost 倍(元の速さの3倍など)になる
##   ・ボスが前(画面の下)へ出ている間は、少し遅くなる(Forward Factor 倍)
##   ・ボスが後ろ(上)へ戻ると、また元の Boost 倍に戻る
##   ・ボスが倒されると、End Multiplier 倍へゆっくり戻る
## 速さは StageRunner のスクロール倍率(ScrollSpeedEvent と同じもの)を変える。

## ボス戦のスクロールの倍率(1 で元の速さ)
@export var boost : float = 3.0
## ボスが前へ出ている間の倍率(Boost に掛ける。0.7 なら3倍 → 2.1倍)
@export var forward_factor : float = 0.7
## ボスが後ろへ戻っている間の倍率(Boost に掛ける。1 なら Boost のまま。1 より大きくすると、戻るときに少し加速する)
@export var back_factor : float = 1.0
## この速さ(px/秒)より速く前後に動いていたら、「前へ出ている」「後ろへ戻っている」とみなす
@export var move_threshold : float = 12.0
## 倍率が変わる速さ(大きいほど、すぐ変わる)
@export var follow : float = 3.0
## 出現してから Boost 倍になるまでの時間(秒)
@export var start_time : float = 1.5
## 倒されたあとの倍率と、そこへ戻る時間(秒)
@export var end_multiplier : float = 1.0
@export var end_time : float = 2.0

var _enemy : Enemy
var _runner : StageRunner
var _last_y : float = 0.0
var _age : float = 0.0
var _ended : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("BossScrollBoost: 親が Enemy ではありません")
		return
	_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	_enemy.died.connect(_on_died)
	_last_y = _enemy.global_position.y

func _physics_process(delta : float) -> void:
	if _ended or _runner == null or not is_instance_valid(_enemy) or delta <= 0.0:
		return
	_age += delta
	var vy := (_enemy.global_position.y - _last_y) / delta # プラスで前(画面の下)へ
	_last_y = _enemy.global_position.y
	var target := boost
	if vy > move_threshold:
		target = boost * forward_factor
	elif vy < -move_threshold:
		target = boost * back_factor
	# 出現した直後は、今の速さから Boost 倍まで、なめらかに上げる
	var ramp := clampf(_age / maxf(start_time, 0.01), 0.0, 1.0)
	target = lerpf(_runner.scroll_multiplier, target, ramp)
	_runner._apply_scroll(lerpf(_runner.scroll_multiplier, target, minf(follow * delta, 1.0)))

func _on_died(_dead : Enemy) -> void:
	_ended = true
	if is_instance_valid(_runner):
		_runner.set_scroll_speed(end_multiplier, end_time)
