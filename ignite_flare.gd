extends Area2D
class_name IgniteFlare
## イグナイト中に、自機が通った跡に残る火。life 秒かけて縮んで消える。
## 触れた敵弾を反射弾にする。横に動けば、横一列の火の壁になる。
## IgniteAura が生成するので、シーンに置く必要はない。

var _params : IgniteParams
var _mask : int = 0
var _radius : float = 20.0
var _life : float = 3.5
var _chain_window_msec : int = 2000

func setup(params : IgniteParams, mask : int, radius : float, life : float, chain_window : float) -> void:
	_params = params
	_mask = mask
	_radius = radius
	_life = life
	_chain_window_msec = int(chain_window * 1000.0)

func _ready() -> void:
	collision_layer = 0
	collision_mask = _mask
	monitorable = false

	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape_node.shape = circle
	add_child(shape_node)
	area_entered.connect(_on_area_entered)

	# 縮みながら薄くなって消える(判定も一緒に縮む)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.15, 0.15), _life)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, _life)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.45, 0.1, 0.35))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(1.0, 0.7, 0.2, 0.9), 2.0)

func _on_area_entered(area : Area2D) -> void:
	if area is EnemyBullet and area.is_normal():
		area.ignite(_params, Time.get_ticks_msec() + _chain_window_msec, false)
