extends Node
class_name WreckExit
## 倒された敵が、壊れたまま画面の下へ走り去ってから消える部品。敵(Enemy)の子に置く(列車のボスなど)。
## 敵の Keep After Death をオンにしておく(オフでも、この部品がオンにする)。
## 倒されると、見た目を暗くして、ゆっくり下へ下がっていき、画面の下の外へ出きったら消える。
## 爆発(DeathExplosion)は、下がりながら起こる。大爆発のあとも、姿は消さない(DeathExplosion の Fade Out Body をオフにする)。

## 暗くする見た目。空なら、敵の子の Node2D(VisualRoot / Sprite2D)を全部
@export var visual : CanvasItem
@export var wreck_color : Color = Color(0.45, 0.4, 0.38)
## 下がる速さ(px/秒)の始めと、加速(px/秒²)と、いちばん速いとき
@export var start_speed : float = 20.0
@export var acceleration : float = 70.0
@export var max_speed : float = 320.0
## 下がり始めるまでの時間(秒)。そのあいだ、その場で爆発する
@export var delay : float = 0.6
## 敵の位置から、見た目の上の端までの距離(px)。上の端が画面の下に出たら消す
@export var top_extent : float = 900.0

var _enemy : Enemy
var _speed : float = 0.0
var _running : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.keep_after_death = true
	var death := DeathExplosion.of(_enemy)
	if death:
		death.fade_out_body = false # 大爆発のあとも、壊れた姿のまま下がっていく
	_enemy.died.connect(_on_died)
	set_physics_process(false)

func _on_died(_e : Enemy) -> void:
	# 走り去るまでは「通り過ぎる列車」と同じ扱いにする(WaitClearEvent の Include Trains が、見えなくなるまで待つ)
	_enemy.add_to_group("train")
	var targets : Array = [visual] if visual else _enemy.get_children().filter(func(n : Node) -> bool: return n is Node2D and not n is EnemyShooter)
	for t in targets:
		var tween := create_tween()
		tween.tween_property(t, "modulate", wreck_color, 0.6)
	_speed = start_speed
	await get_tree().create_timer(delay, false).timeout
	_running = true
	set_physics_process(true)

func _physics_process(delta : float) -> void:
	if not _running or not is_instance_valid(_enemy):
		return
	_speed = minf(_speed + acceleration * delta, max_speed)
	_enemy.global_position.y += _speed * delta
	var view := CameraView.visible_rect(_enemy)
	if _enemy.global_position.y - top_extent > view.end.y:
		_enemy.queue_free()
