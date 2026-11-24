extends Node
class_name BossWreck
## (新しく足したクラスは、エディタがクラス名を覚える前でも動くように、ファイルを直接読み込んで使う)
const _SmokePuff := preload("res://GameScene/Effect/smoke_puff.gd")
## 地上のボス(戦車など)が倒されたあと、壊れた姿のまま、その場に残る部品。ボス(Enemy)の子に置く。
## 倒されると: 動き(移動・揺れ・アニメ)を止め、見た目を焼けた色にして、大爆発のあとも姿を消さない。
## 残骸は地面(背景)と一緒に流れ、煙と小さな火が立ちのぼり続ける。画面の下へ出たら消える。

## 焼けた色
@export var wreck_color : Color = Color(0.42, 0.37, 0.35)
## 煙と火の出る範囲(ボスの位置からの四角。空なら DeathExplosion の Area)
@export var area : Rect2 = Rect2()
## 煙を出す間隔(秒)と大きさ
@export var smoke_interval : float = 0.22
@export var smoke_size : float = 12.0
## 消えるのは、ボスの位置が画面の下からこれだけ出たとき(px)
@export var free_margin : float = 260.0

var _enemy : Enemy
var _ground : Node2D
var _local : Vector2
var _smoke_in : float = 0.0
var _wrecked : bool = false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_enemy.keep_after_death = true
	var death := DeathExplosion.of(_enemy)
	if death:
		death.fade_out_body = false # 大爆発のあとも、壊れた姿を残す
		if area.size == Vector2.ZERO:
			area = death.area
	if area.size == Vector2.ZERO:
		area = Rect2(-60, -60, 120, 120)
	_enemy.died.connect(_on_died)
	set_process(false)

func _on_died(_e : Enemy) -> void:
	_wrecked = true
	_stop_everything(_enemy, self)
	for node in _visuals(_enemy):
		var tween : Tween = node.create_tween()
		tween.tween_property(node, "modulate", wreck_color, 1.2)
	# 地面と一緒に流れる(背景のスクロールに、ぴったりくっつく)
	_ground = get_tree().get_first_node_in_group("ground") as Node2D
	if _ground == null:
		_ground = get_tree().get_first_node_in_group("background_scroller") as Node2D
	if _ground:
		_local = _ground.to_local(_enemy.global_position)
	set_process(true)
	process_priority = 200

func _process(delta : float) -> void:
	if not is_instance_valid(_enemy):
		return
	if _ground and is_instance_valid(_ground):
		_enemy.global_position = _ground.to_global(_local)
	_smoke_in -= delta
	if _smoke_in <= 0.0:
		_smoke_in = smoke_interval * randf_range(0.7, 1.3)
		var at := _enemy.global_position + area.position + Vector2(randf() * area.size.x, randf() * area.size.y) * Vector2(1.0, 0.8)
		_SmokePuff.spawn(get_tree(), at, smoke_size * randf_range(0.7, 1.3), Vector2(randf_range(-8, 8), -randf_range(18, 34)), 1.6)
		if randf() < 0.35:
			BurnPuff.spawn(get_tree(), at)
	var view := CameraView.visible_rect(_enemy)
	if _enemy.global_position.y - free_margin > view.end.y:
		_enemy.queue_free()

## 持ち主を動かす部品(移動・ステート・アニメ)を止める。見た目・爆発・音・自分は止めない
static func _stop_everything(enemy : Node, keep : Node) -> void:
	for child in enemy.get_children():
		if child == keep or child is CanvasItem or child is DeathExplosion or child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED
	for node in enemy.find_children("*", "", true, false):
		if node is AnimationPlayer:
			(node as AnimationPlayer).pause()
		elif node is TextureCycle or node is BeamShooter:
			node.process_mode = Node.PROCESS_MODE_DISABLED

## 色を変える見た目(子の Node2D。砲口は除く)
static func _visuals(enemy : Node) -> Array:
	return enemy.get_children().filter(func(n : Node) -> bool: return n is CanvasItem and not n is EnemyShooter and not n is Hurtbox)
