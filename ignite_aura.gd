extends Area2D
class_name IgniteAura
## イグナイト中に自機の周りに出るオーラ。触れた敵弾を変色(着火)させる。
## Player の子ノード "IgniteAura"(Area2D)にアタッチする。
## Collision Layer は0、Collision Mask は「敵弾のレイヤー」にする。
## 見た目は IgniteVisual(Ignite シーン)が担当する。
##   - Visual に指定する、または、このノードの子孫に置くと自動で見つかる
##   - 無い場合は、簡易的な円を描画する

@export var params : IgniteParams
## 見た目(Ignite シーンのルート)。未指定なら、子孫から自動で探す
@export var visual : IgniteVisual

@export_group("オーラ")
## オーラ半径 = base_radius + radius_per_level × レベル
## (半径はレベルで決まり、時間では変化しない)
@export var base_radius : float = 60.0
@export var radius_per_level : float = 15.0
## 見た目(IgniteVisual)が無いときの簡易円の色
@export var fallback_color : Color = Color(1.0, 0.45, 0.1, 0.25)

var _shape_node : CollisionShape2D
var _radius : float = 0.0
var _fallback_on : bool = false
var _chain_until_msec : int = 0

func _ready() -> void:
	if params == null:
		params = IgniteParams.new()
	if params.ignited_collision_layer == 0 or params.ignited_collision_mask == 0:
		push_warning("IgniteAura: IgniteParams の ignited_collision_layer / mask が未設定です。反射弾が敵に当たらず、連鎖もしません")

	# 見た目を探す(直下でなくても、子孫にあれば見つかる)
	if visual == null:
		var found := find_children("*", "IgniteVisual", true, false)
		if not found.is_empty():
			visual = found[0] as IgniteVisual
	if visual == null:
		push_warning("IgniteAura: IgniteVisual(Ignite シーン)が見つかりません。簡易の円で表示します。Visual に指定するか、IgniteAura の子にしてください")

	# 当たり判定のシェイプ。無ければ自動で作る
	var shapes := find_children("*", "CollisionShape2D", false, false)
	if shapes.is_empty():
		push_warning("IgniteAura: CollisionShape2D が子にないため、自動で作成しました")
		_shape_node = CollisionShape2D.new()
		add_child(_shape_node)
	else:
		_shape_node = shapes[0] as CollisionShape2D
	_shape_node.shape = CircleShape2D.new()

	monitoring = false
	area_entered.connect(_on_area_entered)

func activate(level : int, duration : float) -> void:
	_radius = base_radius + radius_per_level * level
	_chain_until_msec = Time.get_ticks_msec() + int(duration * 1000.0)

	# 見た目を先に出す(当たり判定側で何かあっても、表示は止まらないように)
	if visual:
		# 最大レベルのときの半径を 1.0 とした比率で、スプライトを拡縮する
		var max_radius := base_radius + radius_per_level * IgniteGauge.MAX_LEVEL
		visual.show_aura(level, _radius / max_radius, duration)
	else:
		_fallback_on = true
		queue_redraw()

	(_shape_node.shape as CircleShape2D).radius = _radius
	set_deferred("monitoring", true)

func deactivate() -> void:
	set_deferred("monitoring", false)
	if visual:
		visual.hide_aura()
	else:
		_fallback_on = false
		queue_redraw()

func _draw() -> void:
	if _fallback_on and _radius > 0.0:
		draw_circle(Vector2.ZERO, _radius, fallback_color)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color(fallback_color, 0.9), 2.0)

func _on_area_entered(area : Area2D) -> void:
	if area is EnemyBullet and not area.is_ignited():
		area.ignite(params, _chain_until_msec, false)
