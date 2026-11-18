extends Node2D
class_name SkyBackground
## 空中戦の背景(ステージ3)。ステージのシーンに置く。カメラに映っている範囲に、奥から順に描く:
##   1. 夕焼けの空(上から下へのグラデーション)
##   2. はるか下を流れる海(絵を縦に繰り返し、夕日の色に寄せて霞ませる)
##   3. 一番下の雲: 画面の左右に寄った雲の土手(ゆっくり流れる)
##   4. 背景の敵の群れ(BackgroundSwarm。小さく薄い編隊が、雲のあいだを飛び回る)
##   5. 中層の雲: いろいろな形の雲(雲の隙間から海が見える)
##   6. 上層の雲(速く流れる。薄くして、敵や弾の邪魔をしない)
## 飛行の動き: 背景全体をゆっくり回し(ロール)、斜めに傾け(奥行き)、雲の層ごとに横へずらして(旋回)、
## 空を飛び回っているように見せる。敵・弾・自機は動かさない(背景だけ)。
## 流れる速さには、StageRunner のスクロール倍率(ScrollSpeedEvent・ボス戦の加速)が掛かる。
##
## 擬似3D: 背景は SubViewport に描いてから、sky_projection.gdshader で画面に映す。
##   ステージの "sky_phase" シグナルが来ると、背景が奥へ倒れて(遠近)、進む向きを軸にした筒のように曲がり、
##   風の筋とともに加速する。そのフェーズで出てくるザコ敵の影が、下や左右からグループごとに集まって、
##   画面の中央の奥で待機する。グループが襲ってくる時刻が近づくと、そのグループが離れて、
##   敵が出てくる場所(画面の上下左右どこでも)へ飛んでいき、本物の敵と入れ替わる。
##   グループが離れるときは、筒を回す(ロール)カメラワークで、襲来を見せる。

const CLOUD_SHADER := preload("res://Shaders/sky_clouds.gdshader")
const PROJECTION_SHADER := preload("res://Shaders/sky_projection.gdshader")
## 空と海を、描画範囲の何倍の大きさで描くか(背景を回転・傾けても、端が描画範囲の中に入らないように)
const UNDER_MARGIN : float = 1.8

@export_group("空")
## 空の色(上・真ん中・下)。日が沈んだあとの、青い夕暮れ(下ほど霞んで、藤色がかる)
@export var sky_top : Color = Color(0.38, 0.46, 0.66)
@export var sky_middle : Color = Color(0.46, 0.56, 0.72)
@export var sky_bottom : Color = Color(0.6, 0.56, 0.64)

@export_group("海")
## はるか下の海の絵(縦につながる絵)。空なら出さない
@export var sea_texture : Texture2D
## 絵が横に何コマ並んでいるか(1コマ目を使う)
@export var sea_hframes : int = 1
## 大きさがあれば、絵のこの範囲(px)だけを切り出して、縦に繰り返す(絵の中の文字などを避ける)
@export var sea_region : Rect2i = Rect2i()
## 海の大きさの倍率と、流れる速さ(px/秒)
@export var sea_scale : float = 1.0
@export var sea_speed : float = 24.0
## 海の色(夕日の色に寄せて、霞ませる)
@export var sea_tint : Color = Color(0.4, 0.48, 0.7, 0.25)

@export_group("雲")
## 雲の日なたの色(夕日の桃色)と、陰の色(藤色)。中間や暗い陰の色は、シェーダー(sky_clouds)の設定
@export var cloud_color : Color = Color(0.96, 0.66, 0.52)
@export var cloud_shadow : Color = Color(0.69, 0.5, 0.53)
## 一番下の雲(左右に寄った雲): 量・流れる速さ・不透明度・左右に寄せる強さ
@export var side_coverage : float = 0.4
@export var side_speed : float = 0.07
@export var side_opacity : float = 0.9
@export var side_bias : float = 0.45
## 中層の雲: 量・流れる速さ(画面の高さ / 秒)・不透明度
@export var low_coverage : float = 0.3
@export var low_speed : float = 0.12
@export var low_opacity : float = 0.95
## 上の雲: 量・流れる速さ・不透明度
@export var high_coverage : float = 0.2
@export var high_speed : float = 0.35
@export var high_opacity : float = 0.35

@export_group("飛行の動き")
## 動きの強さ(0 で動かない、1 で標準)
@export var motion_strength : float = 1.0
## ロール(背景を回す)のいちばん大きい角度(度)
@export var roll_deg : float = 12.0
## 傾き(斜めにゆがめて、奥行きを出す)のいちばん大きい量
@export var skew_amount : float = 0.12
## 旋回(雲を横へ流す)の速さ(画面の幅 / 秒)
@export var yaw_speed : float = 0.09
## 背景を、画面より何倍大きく描くか(回したときに、すみが見えないように)
@export var oversize : float = 1.8
## 雑魚の場面では、ななめ上へ進む(背景がななめに流れる)。その角度(度)と、左右を切り替える間隔(秒)
@export var flow_angle_deg : float = 24.0
@export var flow_switch_time : float = 11.0
## ステージの時間がこれを過ぎたら、まっすぐ前へ進む(決戦の前)。負ならしない。
## ボス・中ボスが出ているあいだも、まっすぐ前へ進む
@export var forward_after_time : float = -1.0
## ステージの時間がこの秒数になるまでは、背景の群れ(と影)を出さない(最初のボスの顔見せを邪魔しないように)。0 なら最初から
@export var swarm_after_time : float = 0.0

@export_group("擬似3D(奥行き・筒)")
## 奥行きの場面での、遠近の強さ(背景が奥へ倒れる量)と、筒の曲がり
@export_range(0.0, 0.8) var depth_tilt : float = 0.62
@export_range(0.0, 1.2) var depth_curve : float = 0.55
## 平らな背景から、奥行きの場面へ移るのにかける時間(秒)
@export var depth_transition_time : float = 3.0
## 奥行きの場面では、ゆっくりした回転・傾きを、この割合まで弱める(筒のロールを主役にする)
@export_range(0.0, 1.0) var depth_calm : float = 0.3
## 遠く(画面の上)の霞みと、筒の端の暗さ
@export_range(0.0, 1.0) var depth_haze : float = 0.55
@export_range(0.0, 1.0) var depth_edge_shade : float = 0.5

@export_group("ロール(グループの襲来)")
## 1回のロールで、背景を横へ回す量(画面の幅)と、かける時間(秒)
@export var roll_amount : float = 0.55
@export var roll_time : float = 1.6
## 次のロールまで、少なくともあける時間(秒)
@export var roll_cooldown : float = 5.0
## ロール中に、背景を傾ける角度(度)と、筒をさらに曲げる量
@export var roll_bank_deg : float = 9.0
@export var roll_curve_boost : float = 0.35

@export_group("影の待機")
## 影のグループが、離れてから敵の出てくる場所に着くまでの時間(秒)
@export var launch_time : float = 1.8
## 待機している影の、敵に対する大きさ(遠くにいる)
@export var hold_scale : float = 0.32
## 1グループに出す影の数の上限(敵が多い隊列でも、影はこれまで)
@export var max_shadow_units : int = 5

@export_group("")
## 描く高さ(地面より奥。敵・弾・自機より奥)
@export var background_z : int = -20

var _rig : Node2D
## 背景を描く SubViewport と、それを画面に映す絵
var _vp : SubViewport
var _screen : Sprite2D
var _projection : ShaderMaterial
## 今のカメラの範囲(ワールド座標)
var _view : Rect2 = Rect2(0, 0, 448, 597)
## 擬似3Dの今の量(0 = 平ら、1 = 奥行きの場面)と、今かかっている遠近・筒
var _depth : float = 0.0
var _tilt : float = 0.0
var _curve : float = 0.0
var _depth_started : bool = false
## ロール: 回した量の合計(画面の幅)、進み具合(負なら回していない)、向き、最後に回した時刻
var _roll_offset : float = 0.0
var _roll_from : float = 0.0
var _roll_t : float = -1.0
var _roll_dir : float = 1.0
var _roll_pulse : float = 0.0
var _last_roll : float = -100.0
## 影の待機の予定。{ "event", "time", "launch_at", "texture", "scale", "count", "handoff": 画面の割合,
##   "approach": 背景から近づいてくる敵か, "group", "slot", "launched", "skipped" }
var _plan : Array[Dictionary] = []
## 影が待機する場所(画面の真ん中を 0 とした割合。上がマイナス)と、使っているか
const SLOTS : Array[Vector2] = [
	Vector2(-0.08, -0.30), Vector2(0.08, -0.30), Vector2(-0.24, -0.27), Vector2(0.24, -0.27),
	Vector2(0.0, -0.19), Vector2(-0.17, -0.17), Vector2(0.17, -0.17), Vector2(-0.33, -0.14),
	Vector2(0.33, -0.14), Vector2(-0.09, -0.08), Vector2(0.09, -0.08),
]
var _slot_used : Array[bool] = []
var _entry_turn : int = 0
## 影を出しているイベント(背景から出てくる敵の、ふつうの影を出さないように)
var _staged_events : Dictionary = {}
var _size : Vector2 = Vector2.ONE
var _sky : TextureRect
var _sea : Sprite2D
var _sea_tex : Texture2D
var _sea_frame_w : float = 1.0
var _sea_offset : float = 0.0
var _side : ColorRect
var _side_scroll : float = 0.0
var _low : ColorRect
var _high : ColorRect
var _low_scroll : float = 0.0
var _high_scroll : float = 0.0
var _swarm : BackgroundSwarm
var _time : float = 0.0
var _yaw : float = 0.0
## 進む向き(ラジアン。0 でまっすぐ前、プラスで右ななめ上へ進む)と、目標の向き
var _heading : float = 0.0
var _heading_target : float = 0.0
var _flow_timer : float = 0.0
var _flow_side : float = 1.0
## ななめに進むぶんの、層ごとの横の流れ(画面の幅 = 1)と、海の横の流れ(絵の px)
var _flow_side_layer : float = 0.0
var _flow_low : float = 0.0
var _flow_high : float = 0.0
var _flow_sea : float = 0.0

func _ready() -> void:
	add_to_group("background_scroller") # StageRunner が、スクロールする背景があると分かるように
	add_to_group("sky_background")
	z_as_relative = false
	z_index = background_z
	_slot_used.resize(SLOTS.size())
	_slot_used.fill(false)
	# 背景は SubViewport に描いて、遠近・筒のシェーダーで画面に映す
	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_screen = Sprite2D.new()
	_screen.texture = _vp.get_texture()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_projection = ShaderMaterial.new()
	_projection.shader = PROJECTION_SHADER
	_projection.set_shader_parameter("haze_color", sky_middle)
	_projection.set_shader_parameter("edge_color", sky_top.darkened(0.35))
	_screen.material = _projection
	add_child(_screen)
	_rig = Node2D.new()
	_vp.add_child(_rig)
	# 1. 空
	var gradient := Gradient.new()
	# 空と海は、回転・傾けても端が見えないように、描画範囲より UNDER_MARGIN 倍大きく描く。
	# 色の並びは、まん中の(描画範囲ぶんの)ところで、元と同じになるようにする
	var inner := func(o : float) -> float: return (o * 1.0 + (UNDER_MARGIN - 1.0) * 0.5) / UNDER_MARGIN
	gradient.offsets = PackedFloat32Array([0.0, inner.call(0.0), inner.call(0.55), inner.call(1.0), 1.0])
	gradient.colors = PackedColorArray([sky_top, sky_top, sky_middle, sky_bottom, sky_bottom])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.5, 0.0)
	gradient_texture.fill_to = Vector2(0.5, 1.0)
	gradient_texture.width = 8
	gradient_texture.height = 128
	_sky = TextureRect.new()
	_sky.texture = gradient_texture
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(_sky)
	# 2. 海
	if sea_texture:
		_sea_tex = sea_texture
		_sea_frame_w = float(sea_texture.get_width()) / maxi(sea_hframes, 1)
		if sea_region.size.x > 0 and sea_region.size.y > 0:
			var image := sea_texture.get_image()
			if image:
				if image.is_compressed():
					image.decompress()
				_sea_tex = ImageTexture.create_from_image(image.get_region(sea_region))
				_sea_frame_w = float(sea_region.size.x)
		_sea = Sprite2D.new()
		_sea.texture = _sea_tex
		_sea.centered = false
		_sea.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR # 鏡写しで繰り返して、つなぎ目で途切れないように
		_sea.region_enabled = true
		_sea.modulate = sea_tint
		_rig.add_child(_sea)
	# 3. 一番下の雲(左右)
	_side = _make_clouds(side_coverage, side_opacity)
	var side_material := _side.material as ShaderMaterial
	side_material.set_shader_parameter("side_bias", side_bias)
	side_material.set_shader_parameter("side_width", 0.42) # 背景を大きく描くぶん、端の雲を広めに
	side_material.set_shader_parameter("cloud_scale", 1.3)
	side_material.set_shader_parameter("puff_density", 12.0) # 大きく描く層ほど、こぶを細かくして、こぶの大きさをそろえる
	# 4. 背景の敵の群れ
	_swarm = BackgroundSwarm.new()
	_swarm.quiet = swarm_after_time > 0.0
	_swarm.map_screen = screen_to_local
	_rig.add_child(_swarm)
	# 5・6. 中層・上層の雲
	_low = _make_clouds(low_coverage, low_opacity)
	_high = _make_clouds(high_coverage, high_opacity)
	# 上の雲は薄いので、小さなこぶの集まりにして、ひとつの塊(卵のような形)に見えないようにする
	(_high.material as ShaderMaterial).set_shader_parameter("puff_density", 15.0)
	_follow_view()
	_connect_runner.call_deferred()

## 背景から出てくる敵がもうすぐ来ると知らせてもらう(背景に同じ編隊の影を出す)
func _connect_runner() -> void:
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	# 途中から始めたとき(ここから試遊など): もう奥行きの場面に入っていれば、すぐにそうして影を集める
	if runner and runner.signal_passed("sky_phase"):
		start_depth(true)
		_assemble()
	if runner and not runner.enemy_incoming.is_connected(_on_enemy_incoming):
		runner.enemy_incoming.connect(_on_enemy_incoming)
	if runner and not runner.stage_signal.is_connected(_on_stage_signal):
		runner.stage_signal.connect(_on_stage_signal)

## ボス・中ボスの WARNING が出たら、背景の群れは画面の外へ去っていく。
## "sky_phase" が来たら、奥行きの場面にして(1回目だけ)、このフェーズの敵の影を集める
func _on_stage_signal(signal_name : String, _text : String) -> void:
	if signal_name == "warning" and _swarm:
		_swarm.scatter()
		_plan.clear()
		_slot_used.fill(false)
	elif signal_name == "sky_phase":
		start_depth()
		_assemble()

## 平らな背景から、奥行きの場面へ移る(背景が奥へ倒れ、筒のように曲がり、風の筋とともに加速する)
func start_depth(instant : bool = false) -> void:
	if _depth_started:
		return
	_depth_started = true
	if _swarm:
		_swarm.ambient = false # 適当に飛び回る群れは出さない(影はフェーズの敵だけ)
	if instant:
		_depth = 1.0
		return
	var tween := create_tween()
	tween.tween_property(self, "_depth", 1.0, depth_transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 風を浴びて加速する: 風の筋が強く吹いて、おさまる
	var streaks := DashStreaks.new()
	get_tree().current_scene.add_child(streaks)
	streaks.z_index = background_z + 5 # 背景より手前、敵・弾・自機より奥
	var wind := streaks.create_tween()
	wind.tween_property(streaks, "amount", 0.8, depth_transition_time * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wind.tween_property(streaks, "amount", 0.0, depth_transition_time * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	wind.tween_callback(streaks.queue_free)

## このフェーズ(次の WARNING まで)に出てくるザコ敵を調べて、影の待機の予定を作る
func _assemble() -> void:
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if runner == null or _swarm == null:
		return
	for entry in runner.upcoming_spawns("warning"):
		var event : SpawnEvent = entry["event"]
		var info := _info(event.enemy_scene)
		if info["texture"] == null:
			continue
		var handoff := _handoff_point(event, info)
		_staged_events[event] = true
		_plan.append({"event": event, "time": entry["time"], "launch_at": float(entry["time"]) - launch_time,
			"texture": info["texture"], "scale": info["scale"], "count": mini(event.unit_count(), max_shadow_units),
			"handoff": (handoff - _view.get_center()) / _view.size, "approach": event.emerge == 1,
			"group": {}, "slot": -1, "launched": false, "skipped": false})

## 敵が最初に見える場所(ワールド座標)。影はここへ飛んでいって、本物の敵と入れ替わる
func _handoff_point(event : SpawnEvent, info : Dictionary) -> Vector2:
	var view := _view
	var axis := view.get_center().x
	var mirror := func(p : Vector2) -> Vector2:
		return Vector2(axis * 2.0 - p.x, p.y) if event.mirror_x else p
	if event.flight_curve:
		var first : Vector2 = event.flight_curve.center + event.flight_curve.point(0.0) + event.offset
		return Vector2(first.x, view.position.y + 10.0)
	var pattern : MovePattern = event.move_pattern if event.move_pattern else info["pattern"]
	var start := Vector2(axis, view.position.y - 40.0)
	var target := Vector2(axis, view.position.y + view.size.y * 0.25)
	if pattern:
		start = pattern.start_position
		target = start
		for step in pattern.steps:
			if step.mode != MoveStep.Mode.CHASE:
				target = start + step.target if step.relative else step.target
			break
	start = mirror.call(start + event.offset)
	target = mirror.call(target + event.offset)
	match event.emerge:
		1: # 背景から近づいてくる: 最初に向かう地点の、少し上
			return target + Vector2(0.0, -30.0)
		2: # 背景の下から上へ抜ける: 画面の下のほう
			return Vector2(target.x, view.end.y - view.size.y * 0.15)
	# ふつう: 画面の外の出現位置を、画面のふちに寄せた場所(そこから入ってくる)
	var inner := view.grow(-12.0)
	return start.clamp(inner.position, inner.end)

## 影の待機の予定を進める: 空いた場所に次のグループを呼び、時刻が来たグループを送り出す
func _update_plan(now : float) -> void:
	for i in range(_plan.size() - 1, -1, -1):
		var item := _plan[i]
		var group : Dictionary = item["group"]
		if item["skipped"] or (item["launched"] and (group.is_empty() or group.get("state", "") == "done")):
			_plan.remove_at(i)
	for item in _plan:
		if item["skipped"] or item["launched"]:
			continue
		var left : float = item["launch_at"] - now
		if (item["group"] as Dictionary).is_empty():
			if left < 0.8:
				item["skipped"] = true # 間に合わない
				continue
			var slot := _free_slot()
			if slot < 0:
				continue
			_slot_used[slot] = true
			item["slot"] = slot
			# 下・左・右から順に入ってくる(時間がなければ、待機する場所にそのまま浮かび上がる)
			var from := SLOTS[slot]
			if left >= 3.0:
				match _entry_turn % 3:
					0: from = Vector2(SLOTS[slot].x * 1.6, 0.85)
					1: from = Vector2(-0.95, SLOTS[slot].y + 0.25)
					_: from = Vector2(0.95, SLOTS[slot].y + 0.25)
				_entry_turn += 1
			item["group"] = _swarm.stage_group(item["texture"], item["scale"] * hold_scale, item["count"], SLOTS[slot], from)
		elif left <= 0.0:
			item["launched"] = true
			_slot_used[item["slot"]] = false
			var seconds := maxf(float(item["time"]) - now, 0.4)
			var arrive : float = item["scale"] * (0.3 if item["approach"] else 0.75)
			_swarm.launch_group(item["group"], item["handoff"], seconds, arrive, not item["approach"])
			_try_roll(signf((item["handoff"] as Vector2).x))

func _free_slot() -> int:
	var free : Array[int] = []
	for i in SLOTS.size():
		if not _slot_used[i]:
			free.append(i)
	return -1 if free.is_empty() else free.pick_random()

## グループが襲ってくるときに、筒を回す(間隔があいていれば)。向きは、襲ってくる側へ
func _try_roll(side : float) -> void:
	if _depth < 0.5 or _time - _last_roll < roll_cooldown or _roll_t >= 0.0:
		return
	_last_roll = _time
	_roll_t = 0.0
	_roll_from = _roll_offset
	_roll_dir = side if side != 0.0 else (-1.0 if randf() < 0.5 else 1.0)

## 敵のシーンの絵・大きさ・移動パターン(影を作るために、1回だけ調べて覚えておく)
var _scene_info : Dictionary = {}

func _info(scene : PackedScene) -> Dictionary:
	if _scene_info.has(scene):
		return _scene_info[scene]
	var info := {"texture": null, "scale": 1.0, "pattern": null}
	var enemy := scene.instantiate() as Node2D
	if enemy:
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			info["texture"] = sprite.texture
			info["scale"] = absf(sprite.scale.x * enemy.scale.x)
		info["pattern"] = enemy.get("pattern")
		enemy.free()
	_scene_info[scene] = info
	return info

func _on_enemy_incoming(event : SpawnEvent, seconds : float) -> void:
	if _swarm == null or event.enemy_scene == null or _staged_events.has(event):
		return
	var info := _info(event.enemy_scene)
	var pattern : MovePattern = event.move_pattern if event.move_pattern else info["pattern"]
	var base := Vector2(240.0, 140.0)
	if pattern:
		base = pattern.start_position
		for step in pattern.steps:
			if step.mode != MoveStep.Mode.CHASE:
				base = base + step.target if step.relative else step.target
			break
	var points : Array[Vector2] = []
	for i in event.unit_count():
		var world := base + event.offset + event.offset_step * i
		points.append(screen_to_local((world - _view.get_center()) / _view.size))
	_swarm.foreshadow(info["texture"], points, seconds, info["scale"])

func _make_clouds(coverage : float, opacity : float) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	material.set_shader_parameter("cloud_color", cloud_color)
	material.set_shader_parameter("shadow_color", cloud_shadow)
	material.set_shader_parameter("coverage", coverage)
	material.set_shader_parameter("sky_alpha", 0.0) # 雲の隙間から、下が見える
	material.set_shader_parameter("opacity", opacity)
	rect.material = material
	# 四角形は、回転・傾けた背景(_rig)の動きを打ち消す台に載せて、描画範囲にまっすぐ・いっぱいに置く。
	# 回転・傾き・寄りは、シェーダーが座標で付ける(四角形ごと回すと、端が描画範囲の中に入って雲が切れる)
	var holder := Node2D.new()
	holder.add_child(rect)
	_rig.add_child(holder)
	return rect

## 背景の敵の群れ(雲のあいだを飛ぶ)
func swarm() -> BackgroundSwarm:
	return _swarm

func _process(delta : float) -> void:
	_time += delta
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	var speed := runner.scroll_multiplier if runner else 1.0
	_sea_offset += sea_speed * speed * delta
	_side_scroll += side_speed * speed * delta
	_low_scroll += low_speed * speed * delta
	_high_scroll += high_speed * speed * delta
	# 旋回: ゆっくり左右に向きを変えながら、雲を横へ流す
	var k := motion_strength
	_yaw += yaw_speed * k * (sin(_time * 0.11) + 0.6 * sin(_time * 0.29 + 2.0)) * delta
	# 進む向き: 雑魚の場面はななめ上(ときどき左右を切り替える)、ボス・中ボスのときと決戦の前はまっすぐ前
	var forward := (forward_after_time >= 0.0 and runner and runner.stage_time >= forward_after_time) 		or not get_tree().get_nodes_in_group("stage_boss").is_empty() 		or not get_tree().get_nodes_in_group("stage_midboss").is_empty()
	_flow_timer -= delta
	if _flow_timer <= 0.0:
		_flow_timer = flow_switch_time * randf_range(0.8, 1.2)
		_flow_side = -_flow_side
	_heading_target = 0.0 if forward else deg_to_rad(flow_angle_deg) * _flow_side * k
	_heading = move_toward(_heading, _heading_target, delta * 0.35)
	# ななめに進むぶん、背景を横へも流す(縦に流れた量 × tan(向き)。画面の幅に直す)
	var slant := tan(_heading) * (_size.y / maxf(_size.x, 1.0))
	_flow_side_layer += slant * side_speed * speed * delta
	_flow_low += slant * low_speed * speed * delta
	_flow_high += slant * high_speed * speed * delta
	_flow_sea += tan(_heading) * sea_speed * speed * delta
	# ロール(筒を回す): ゆっくり加速して回り、ゆっくり止まる。回っているあいだは傾いて、筒がさらに曲がる
	_roll_pulse = 0.0
	if _roll_t >= 0.0:
		_roll_t += delta / maxf(roll_time, 0.1)
		var w := smoothstep(0.0, 1.0, minf(_roll_t, 1.0))
		_roll_offset = _roll_from + _roll_dir * roll_amount * w
		_roll_pulse = sin(PI * minf(_roll_t, 1.0))
		if _roll_t >= 1.0:
			_roll_t = -1.0
	_tilt = depth_tilt * _depth
	_curve = depth_curve * _depth + roll_curve_boost * _roll_pulse * _depth
	_projection.set_shader_parameter("tilt", _tilt)
	_projection.set_shader_parameter("curve", _curve)
	_projection.set_shader_parameter("haze", depth_haze * _depth)
	_projection.set_shader_parameter("edge_shade", depth_edge_shade * _depth)
	(_side.material as ShaderMaterial).set_shader_parameter("scroll", _side_scroll)
	(_low.material as ShaderMaterial).set_shader_parameter("scroll", _low_scroll)
	(_high.material as ShaderMaterial).set_shader_parameter("scroll", _high_scroll)
	(_side.material as ShaderMaterial).set_shader_parameter("drift", _yaw * 0.5 + _flow_side_layer + _roll_offset * 0.6)
	(_low.material as ShaderMaterial).set_shader_parameter("drift", _yaw * 1.0 + _flow_low + _roll_offset * 0.8)
	(_high.material as ShaderMaterial).set_shader_parameter("drift", _yaw * 1.7 + _flow_high + _roll_offset * 1.0)
	if _swarm:
		_swarm.scroll_speed = speed
		_swarm.quiet = swarm_after_time > 0.0 and (runner == null or runner.stage_time < swarm_after_time)
	_follow_view()
	if runner and not _plan.is_empty():
		_update_plan(runner.stage_time)

## カメラに映っている範囲の真ん中に、背景を回して・傾けて置く
func _follow_view() -> void:
	var view := CameraView.visible_rect(self)
	_view = view
	# 奥行きの場面では、ゆっくりした回転・傾きを弱めて、筒のロールを主役にする
	var k := motion_strength * lerpf(1.0, depth_calm, _depth)
	_size = (view.size * oversize).round()
	var vp_size := Vector2i(_size)
	if _vp.size != vp_size:
		_vp.size = vp_size
	# 背景の絵(SubViewport)を、画面いっぱいに映す
	_screen.global_position = view.get_center()
	_screen.scale = view.size / _size
	_projection.set_shader_parameter("oversize", Vector2(oversize, oversize))
	_rig.position = _size * 0.5
	# ロール(ゆっくり大きく + 少し速く小さく)と、傾き(奥行き)と、ほんの少しの遠近(寄ったり離れたり)
	_rig.rotation = deg_to_rad(roll_deg) * k * (0.7 * sin(_time * 0.19) + 0.3 * sin(_time * 0.47 + 1.3)) - _heading * 0.35 \
		+ deg_to_rad(roll_bank_deg) * _roll_pulse * _roll_dir * _depth # 筒を回すときは、回る向きへ傾く
	_rig.skew = skew_amount * k * sin(_time * 0.15 + 0.7)
	var zoom := 1.0 + 0.05 * k * sin(_time * 0.23 + 0.4)
	_rig.scale = Vector2(zoom, zoom)
	var corner := -_size * 0.5
	var under := _size * UNDER_MARGIN # 空と海は大きめに描く(回転・傾けても端が見えないように)
	_sky.position = -under * 0.5
	_sky.size = under
	if _sea:
		var frame_w := _sea_frame_w
		var s := maxf(_size.x / frame_w, sea_scale)
		_sea.scale = Vector2(s, s)
		_sea.position = -under * 0.5
		# 縦に繰り返す絵を下へ流し、旋回にあわせて少し横へずらす。
		# 大きく描いたぶん、元の描画範囲の左上が、元と同じ絵の場所になるように始点をずらす
		var extra := (under - _size) * 0.5 / s
		_sea.region_rect = Rect2((_yaw * 0.3 + _roll_offset * 0.4) * frame_w + _flow_sea / s - extra.x, -_sea_offset / s - extra.y, under.x / s, under.y / s)
	var inverse := _rig.transform.affine_inverse() # 描画範囲の px → 背景の中の座標
	for rect in [_side, _low, _high]:
		(rect.get_parent() as Node2D).transform = inverse # _rig の動きを打ち消す
		rect.position = Vector2.ZERO
		rect.size = _size
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("rect_size", _size)
		material.set_shader_parameter("aspect", _size.x / maxf(_size.y, 1.0))
		material.set_shader_parameter("inv_x", inverse.x)
		material.set_shader_parameter("inv_y", inverse.y)
		material.set_shader_parameter("inv_o", inverse.origin)
	if _swarm:
		_swarm.area = Rect2(corner, _size)

# ---------------------------------------------------------------- 画面と背景の対応(sky_projection.gdshader と同じ式)

## 画面の点(画面の真ん中を 0 とした割合。幅・高さ = 1)が、背景の群れ(BackgroundSwarm)のどこに映るか
func screen_to_local(ratio : Vector2) -> Vector2:
	var v := ratio.y / (1.0 + _tilt * ratio.y)
	var xc := ratio.x * (1.0 - _tilt * v)
	var u := xc
	if _curve > 0.001:
		u = asin(clampf(xc * _curve, -1.0, 1.0)) / _curve
	var px := Vector2(u, v) * _view.size + _size * 0.5
	return _rig.transform.affine_inverse() * px

## 背景の群れの点(ローカル座標)が、画面のどこに映るか(ワールド座標)
func local_to_screen(local : Vector2) -> Vector2:
	var px := _rig.transform * local - _size * 0.5
	var u := px.x / _view.size.x
	var v := px.y / _view.size.y
	var xc := sin(u * _curve) / _curve if _curve > 0.001 else u
	var d := 1.0 - _tilt * v
	return _view.get_center() + Vector2(xc / d, v / d) * _view.size
