extends Area2D
class_name IgniteAura
## イグナイトON中の、自機まわりの効果。Player の子ノード "IgniteAura"(Area2D)にアタッチする。
##   ・焼却範囲(円): 最大半径まで一瞬で広がり、その後 final_radius まで縮む。
##                 入った敵弾は、入った瞬間に焼却される(burned シグナル → スコア)
##   ・フレア: 動いた跡に火を残す。触れた敵弾は反射弾になる(火の壁)
## Collision Layer は0、Collision Mask は「敵弾のレイヤー」にする(フレアも同じマスクを使う)。
## 見た目は IgniteVisual(Ignite シーン)が担当する。無い場合は簡易的な円を描画する。

## 焼却した弾の位置を通知する(スコア加算用)
signal burned(bullet_position : Vector2)

## 反射弾の設定(フレアに触れた弾に使われる)
@export var params : IgniteParams
## 見た目(Ignite シーンのルート)。未指定なら、子孫から自動で探す
@export var visual : IgniteVisual
## true なら、オーラに入った物や、発動時に重なっている物を出力する(調査用)
@export var debug_log : bool = false

@export_group("焼却範囲の拡大・縮小")
## 最大半径まで広がる時間(秒)
@export var expand_time : float = 0.15
## 最大半径から最終半径まで縮む時間(秒)
@export var shrink_time : float = 0.4
## 見た目(IgniteVisual)が無いときの簡易円の色
@export var fallback_color : Color = Color(1.0, 0.45, 0.1, 0.25)

@export_group("フレア(通った跡に残る火)")
## 何px動くごとにフレアを置くか
@export var flare_spacing : float = 24.0
## フレアが消えるまでの時間(秒)
@export var flare_life : float = 2.0
## フレアの半径 = base + per_level × レベル
@export var flare_radius_base : float = 20.0
@export var flare_radius_per_level : float = 4.0
## 同時に存在できるフレアの数(超えたら古いものから消える)
@export var max_flares : int = 80
## フレアで反射した弾が、連鎖できる時間(秒)
@export var chain_window : float = 2.0

var _shape_node : CollisionShape2D
var _radius : float = 0.0
var _level : int = 0
var _active : bool = false
var _fallback_on : bool = false
var _radius_tween : Tween
var _flares : Array[IgniteFlare] = []
var _last_flare_pos : Vector2

func _ready() -> void:
	if params == null:
		params = IgniteParams.new()
	if params.ignited_collision_layer == 0 or params.ignited_collision_mask == 0:
		push_warning("IgniteAura: IgniteParams の ignited_collision_layer / mask が未設定です。反射弾が敵に当たらず、連鎖もしません")

	# 見た目を探す(直下でなくても、子孫にあれば見つかる)
	if visual == null:
		visual = _find_visual()
		if visual and not is_ancestor_of(visual):
			push_warning("IgniteAura: Ignite(%s)が IgniteAura の子ではありません。表示はされますが、位置は Ignite 側のノードの位置に従います。IgniteAura の子にするのがおすすめです" % visual.get_path())
	# 古い版の ignite_visual.gd が付いていると set_radius などが無く、Invalid call になる。先に確認する
	if visual != null and not (visual.has_method("set_radius") and visual.has_method("show_aura")):
		push_warning("IgniteAura: %s の ignite_visual.gd が古い版です(set_radius が無い)。最新版に差し替えてください。簡易の円で表示します" % visual.get_path())
		visual = null
	if visual == null:
		push_warning("IgniteAura: IgniteVisual(Ignite シーン)が使えません。簡易の円で表示します")

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

## IgniteVisual を探す。1)自分の子孫 2)親(Player)の子孫 3)シーン全体、の順
func _find_visual() -> IgniteVisual:
	for root in [self, get_parent(), get_tree().current_scene]:
		if root == null:
			continue
		for node in root.find_children("*", "", true, false):
			if node is IgniteVisual:
				return node
	return null

func is_active() -> bool:
	return _active

## ON中のレベルに合わせて効果を整える。
## まだ出ていなければ、最大半径まで広がってから縮む。出ていれば、新しい半径へ縮める
func apply_level(level : int, max_radius : float, final_radius : float) -> void:
	var level_changed := level != _level
	_level = level
	if debug_log:
		print("[IgniteAura] apply_level Lv%d 最大%.0f→%.0f active=%s visual=%s" % [
			level, max_radius, final_radius, _active, visual.get_path() if visual else "なし(簡易の円)"])
	if not _active:
		_active = true
		_kill_radius_tween()
		if visual:
			visual.show_aura(level, 1.0, 0.0)
		else:
			_fallback_on = true
		_set_radius(1.0)
		set_deferred("monitoring", true)
		_last_flare_pos = global_position
		_spawn_flare()
		_radius_tween = create_tween()
		_radius_tween.tween_method(_set_radius, 1.0, max_radius, expand_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_radius_tween.tween_method(_set_radius, max_radius, final_radius, shrink_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if debug_log:
			_debug_report()
	elif level_changed:
		if visual:
			visual.show_aura(level, _radius, 0.0) # 表示するスプライトを、新しいレベルに合わせる
		_kill_radius_tween()
		_radius_tween = create_tween()
		_radius_tween.tween_method(_set_radius, _radius, final_radius, shrink_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 効果を止める(イグナイトOFF、またはゲージが0のとき)
func stop() -> void:
	if not _active:
		return
	_active = false
	_kill_radius_tween()
	set_deferred("monitoring", false)
	if visual:
		visual.hide_aura()
	else:
		_fallback_on = false
		queue_redraw()

func _kill_radius_tween() -> void:
	if _radius_tween:
		_radius_tween.kill()
		_radius_tween = null

func _set_radius(r : float) -> void:
	_radius = maxf(r, 1.0)
	(_shape_node.shape as CircleShape2D).radius = _radius
	if visual:
		visual.set_radius(_radius)
	else:
		queue_redraw()

func _draw() -> void:
	if _fallback_on and _radius > 0.0:
		draw_circle(Vector2.ZERO, _radius, fallback_color)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color(fallback_color, 0.9), 2.0)

# ---------------------------------------------------------------- フレア

func _physics_process(_delta : float) -> void:
	if not _active:
		return
	# 動いた距離が flare_spacing を超えるたびに、フレアを置く(止まっているときは置かない)
	if global_position.distance_to(_last_flare_pos) >= flare_spacing:
		_last_flare_pos = global_position
		_spawn_flare()

func _spawn_flare() -> void:
	var flare := IgniteFlare.new()
	flare.setup(params, collision_mask, flare_radius_base + flare_radius_per_level * _level, flare_life, chain_window)
	get_tree().current_scene.add_child(flare)
	flare.global_position = global_position
	_flares.append(flare)
	flare.tree_exited.connect(func() -> void: _flares.erase(flare))
	while _flares.size() > max_flares:
		var oldest : IgniteFlare = _flares.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

# ---------------------------------------------------------------- 焼却

func _on_area_entered(area : Area2D) -> void:
	if debug_log:
		print("[IgniteAura] 入った: %s / EnemyBullet=%s / layer=%d" % [
			area.get_path(), area is EnemyBullet, area.collision_layer])
	# 範囲に入った敵弾は、入った瞬間に焼却する
	if area is EnemyBullet and area.burn():
		burned.emit(area.global_position)

func _debug_report() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[IgniteAura] monitoring=%s mask=%d 半径=%.0f 重なっているArea=%d個" % [
		monitoring, collision_mask, _radius, get_overlapping_areas().size()])
