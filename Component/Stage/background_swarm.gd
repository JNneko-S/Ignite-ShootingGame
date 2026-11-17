extends Node2D
class_name BackgroundSwarm
## 背景を飛び回る、敵の群れ(ステージ3)。SkyBackground が作り、雲の層のあいだに置く(雲が手前を流れる)。
## ボス・中ボスの WARNING が来たら(scatter)、飛んでいる群れも影も、いっせいに画面の外へ去り、ボス・中ボスがいるあいだは出てこない。
## 小さく薄い(夕暮れの空に溶けた)戦闘機の編隊が、上下左右のいろいろな向きから入ってきて、
## 隊列を組んだまま、まっすぐ抜けたり、ぐるっと宙返りしたり、S字に切り返したりして、いっしょに飛び去っていく。
## 当たり判定はない、見た目だけ。ボス・中ボスが出ているあいだは、群れは薄れて少なくなる。
##
## もうすぐ背景から出てくる敵には、同じ形の「影の編隊」を先に出す(foreshadow)。
## 影の編隊は、端から入ってきて、出てくる地点のまわりを隊列のまま旋回して待ち、最後にその地点へ降りてきて、敵と入れ替わりに消える。

const TEXTURES : Array[String] = [
	"res://Assets/Full Shmup Asset Pack/Medium tiny enemies Asset pack/pp_1.png",
	"res://Assets/Full Shmup Asset Pack/Medium tiny enemies Asset pack/Bl_0.png",
	"res://Assets/Full Shmup Asset Pack/Enm_Model0/0midnight.png",
	"res://Assets/Full Shmup Asset Pack/Medium tiny enemies Asset pack/MG_0.png",
]

## 群れを出す範囲(SkyBackground が、背景の大きさに合わせて入れる。ローカル座標)
var area : Rect2 = Rect2(-300, -400, 600, 800)
## 背景の流れの速さ(StageRunner のスクロール倍率)。速いほど、群れも速く飛ぶ
var scroll_speed : float = 1.0
## 群れの多さ(0〜1)。ボス・中ボスがいると、自動で下がる
var density : float = 1.0
## オンのあいだは、群れも影も出さない(最初のボスの顔見せのあいだなど)。影の知らせは、終わるまで預かる
var quiet : bool = false

## 次の編隊を出すまでの時間(秒。多さが 1 のとき)
@export var group_interval : float = 1.3
## 1編隊の機数
@export var min_count : int = 5
@export var max_count : int = 9
## 大きさと、飛ぶ速さ(px/秒)
@export var min_scale : float = 0.45
@export var max_scale : float = 0.8
@export var min_speed : float = 90.0
@export var max_speed : float = 170.0
## 色(夕暮れの空に溶けた、暗く薄いシルエット)
@export var tint : Color = Color(0.22, 0.14, 0.26, 0.55)

## 影の編隊の、待つあいだの旋回の半径(px)と速さ(px/秒)
@export var orbit_radius : float = 95.0
@export var orbit_speed : float = 150.0

var _textures : Array[Texture2D] = []
## 編隊。{ "units": [{ "node", "offset" }], "pos", "angle", "speed", "plan": [[秒, 回る速さ(rad/秒)], …],
##        "step", "step_t", "age", "texture", "shadow": 影の編隊か, 影なら "center" "points" "end" "dir" }
var _groups : Array[Dictionary] = []
## 静かなあいだに届いた、影の知らせ。{ "texture", "points", "seconds", "scale", "at" }
var _pending : Array[Dictionary] = []
var _timer : float = 0.0
var _time : float = 0.0
var _was_quiet : bool = false
## 去らせたあと、新しい群れを出さない残り時間(秒)
var _hold : float = 0.0

func _ready() -> void:
	for path in TEXTURES:
		var texture := load(path) as Texture2D
		if texture:
			_textures.append(texture)
	if quiet:
		density = 0.0
		_was_quiet = true
		return
	# はじめから何編隊か飛んでいるように
	for i in 3:
		_spawn_group(true)

func _process(delta : float) -> void:
	_time += delta
	# ボス・中ボスがいるあいだは、群れを減らす。静かなあいだは出さない
	var busy := not get_tree().get_nodes_in_group("stage_boss").is_empty() or not get_tree().get_nodes_in_group("stage_midboss").is_empty()
	_hold = maxf(_hold - delta, 0.0)
	var wanted := 0.0 if quiet or busy or _hold > 0.0 else 1.0
	density = move_toward(density, wanted, delta * 0.5)
	if _was_quiet and not quiet:
		_release_pending()
	_was_quiet = quiet
	if not quiet and _hold <= 0.0 and density > 0.05:
		_timer -= delta * density
		if _timer <= 0.0:
			_timer = group_interval * randf_range(0.6, 1.4)
			_spawn_group(false)
	var grown := area.grow(220.0)
	for i in range(_groups.size() - 1, -1, -1):
		var group := _groups[i]
		group["age"] += delta
		if group.get("leave", false):
			_leave(group, delta)
		elif group["shadow"]:
			_update_shadow(group, delta)
		else:
			_fly(group, delta)
		var alpha := _alpha(group)
		var any_inside := false
		for unit in group["units"]:
			var node : Sprite2D = unit["node"]
			node.modulate = Color(tint, alpha)
			if grown.has_point(node.position):
				any_inside = true
		var done : bool
		if group.get("leave", false):
			done = not any_inside or group["leave_alpha"] <= 0.0
		elif group["shadow"]:
			done = group["age"] >= group["end"]
		else:
			done = not any_inside and group["age"] > 3.0
		if done:
			for unit in group["units"]:
				(unit["node"] as Node).queue_free()
			_groups.remove_at(i)

## 編隊の濃さ
func _alpha(group : Dictionary) -> float:
	var age : float = group["age"]
	if group.get("leave", false):
		return tint.a * clampf(group["leave_alpha"], 0.0, 1.0)
	if group["shadow"]:
		var end : float = group["end"]
		return tint.a * clampf(age / 0.8, 0.0, 1.0) * clampf((end - age) / 0.7, 0.0, 1.0)
	return tint.a * density

## 飛んでいる群れも影も、いっせいに画面の外へ去らせる(ボス・中ボスの WARNING)。しばらくは新しい群れを出さない
func scatter(hold : float = 6.0) -> void:
	_hold = maxf(_hold, hold)
	_pending.clear()
	for group in _groups:
		if group.get("leave", false):
			continue
		# 今の濃さのまま去る(出はじめの影は、薄いまま)
		group["leave_alpha"] = maxf(_alpha(group) / maxf(tint.a, 0.01), 0.3)
		group["leave"] = true
		group["leave_t"] = 0.0
		# 画面の真ん中から見て外側へ
		var out : Vector2 = group["pos"] - area.get_center()
		if out.length() < 1.0:
			out = Vector2.from_angle(group["angle"])
		group["leave_angle"] = out.angle()

## 去っていく編隊: 外へ向きを変えながら、速くなって抜けていく。抜けきれないときは薄れて消える
func _leave(group : Dictionary, delta : float) -> void:
	group["angle"] = lerp_angle(group["angle"], group["leave_angle"], minf(delta * 2.5, 1.0))
	group["speed"] = move_toward(group["speed"], 340.0, delta * 260.0)
	group["pos"] += Vector2.from_angle(group["angle"]) * group["speed"] * delta
	group["leave_t"] += delta
	if group["leave_t"] > 2.5:
		group["leave_alpha"] -= delta * 1.5
	_place(group, 1.0)

## ふつうの編隊: 予定(plan)どおりに、まっすぐ飛んだり曲がったりする
func _fly(group : Dictionary, delta : float) -> void:
	var plan : Array = group["plan"]
	var step : int = group["step"]
	var turn := 0.0
	if step < plan.size():
		turn = plan[step][1]
		group["step_t"] += delta
		if group["step_t"] >= plan[step][0]:
			group["step_t"] = 0.0
			group["step"] = step + 1
	group["angle"] += turn * delta
	var speed : float = group["speed"] * clampf(scroll_speed, 0.6, 3.0)
	group["pos"] += Vector2.from_angle(group["angle"]) * speed * delta
	_place(group, 1.0)

## 隊列の形のまま、編隊の向きに合わせて並べる。機首は進む向きへ
func _place(group : Dictionary, spread : float) -> void:
	var angle : float = group["angle"]
	var rot := angle - PI * 0.5 # 隊列の形は「下へ進むとき」で作ってある
	var sway := Vector2(sin(_time * 1.3 + group["phase"]), cos(_time * 1.1 + group["phase"])) * 5.0
	var facing := BackgroundSwarm.facing(group["texture"], Vector2.from_angle(angle))
	for unit in group["units"]:
		var node : Sprite2D = unit["node"]
		node.position = group["pos"] + (unit["offset"] as Vector2).rotated(rot) * spread + sway
		node.rotation = lerp_angle(node.rotation, facing, 0.35)

## 編隊を1つ出す。上下左右のどこかから入って、隊列のまま飛び、いっしょに抜けていく
func _spawn_group(anywhere : bool) -> void:
	if _textures.is_empty():
		return
	var texture : Texture2D = _textures.pick_random()
	var count := randi_range(min_count, max_count)
	var s := randf_range(min_scale, max_scale)
	var speed := randf_range(min_speed, max_speed) * lerpf(0.75, 1.2, (s - min_scale) / maxf(max_scale - min_scale, 0.01)) # 大きい(近い)ほど速い
	var start : Vector2
	var dir : Vector2
	match randi() % 4:
		0: # 上から下へ
			start = Vector2(randf_range(area.position.x, area.end.x) * 0.8, area.position.y - 80.0)
			dir = Vector2(randf_range(-0.4, 0.4), 1.0)
		1: # 下から上へ
			start = Vector2(randf_range(area.position.x, area.end.x) * 0.8, area.end.y + 80.0)
			dir = Vector2(randf_range(-0.4, 0.4), -1.0)
		2: # 左から右へ
			start = Vector2(area.position.x - 80.0, randf_range(area.position.y, area.end.y) * 0.8)
			dir = Vector2(1.0, randf_range(-0.5, 0.5))
		_: # 右から左へ
			start = Vector2(area.end.x + 80.0, randf_range(area.position.y, area.end.y) * 0.8)
			dir = Vector2(-1.0, randf_range(-0.5, 0.5))
	if anywhere:
		start = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)) * 0.8
	var gap := 46.0 * s / 0.36
	var offsets := _formation(count, gap, randi() % 3)
	var group := _make_group(texture, offsets, s, start, dir.angle(), speed, false)
	group["plan"] = _random_plan(speed * clampf(scroll_speed, 0.6, 3.0))
	_groups.append(group)
	_place(group, 1.0)

## 飛び方の予定を1つ選ぶ。[[秒, 回る速さ(rad/秒)], …]。最後はまっすぐ抜ける
func _random_plan(speed : float) -> Array:
	var lead := randf_range(0.6, 1.6) # 少しまっすぐ入ってきてから
	var lr := -1.0 if randf() < 0.5 else 1.0
	# 旋回の半径が 90〜150px になる回り方
	var omega := speed / randf_range(90.0, 150.0)
	match randi() % 5:
		0, 1: # まっすぐ抜ける
			return []
		2: # ぐるっと1回転(宙返り)して、もとの向きへ抜ける
			return [[lead, 0.0], [TAU / omega, omega * lr]]
		3: # S字に切り返す
			var half := (PI * 0.5) / omega
			return [[lead, 0.0], [half, omega * lr], [half * 2.0, -omega * lr], [half, omega * lr]]
		_: # 大きく曲がって、別の向きへ去っていく
			return [[lead, 0.0], [randf_range(0.5, 1.0) * PI / omega, omega * lr]]

## 隊列の形(下へ進むときの並び。先頭が 0)。kind: 0 = V字、1 = ななめの列、2 = 菱形
func _formation(count : int, gap : float, kind : int) -> Array[Vector2]:
	var offsets : Array[Vector2] = []
	for i in count:
		match kind:
			0:
				var row := (i + 1) / 2
				var lr := -1.0 if i % 2 == 0 else 1.0
				offsets.append(Vector2(row * gap * 0.8 * lr, -row * gap))
			1:
				offsets.append(Vector2(i * gap * 0.45, -i * gap * 0.9))
			_:
				# 菱形を、後ろへ重ねていく(1・2・1・2…)
				var row := i / 3
				var col := i % 3
				offsets.append(Vector2((col - 1) * gap * 0.9, -row * gap * 1.6 - (gap * 0.8 if col != 1 else 0.0)))
	return offsets

func _make_group(texture : Texture2D, offsets : Array[Vector2], unit_scale : float, pos : Vector2, angle : float, speed : float, shadow : bool) -> Dictionary:
	var units : Array[Dictionary] = []
	var facing := BackgroundSwarm.facing(texture, Vector2.from_angle(angle))
	for offset in offsets:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(unit_scale, unit_scale)
		sprite.rotation = facing
		sprite.modulate = Color(tint, 0.0)
		add_child(sprite)
		units.append({"node": sprite, "offset": offset})
	return {"units": units, "pos": pos, "angle": angle, "speed": speed, "plan": [], "step": 0, "step_t": 0.0,
		"age": 0.0, "texture": texture, "shadow": shadow, "phase": randf() * TAU}

## もうすぐ来る敵の影の編隊を出す。points は、敵が出てくる地点(このノードのローカル座標)。
## seconds 秒たったら(敵が背景から出てくるので)、その地点へ降りてきて消える
func foreshadow(texture : Texture2D, points : Array[Vector2], seconds : float, unit_scale : float) -> void:
	if texture == null or points.is_empty():
		return
	if quiet:
		_pending.append({"texture": texture, "points": points, "seconds": seconds, "scale": unit_scale, "at": _time})
		return
	if seconds < 2.0:
		return # 間に合わない
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	# 隊列の形: 敵が出てくる並びを、少し詰めたもの(奥にいるので小さく)
	var offsets : Array[Vector2] = []
	for p in points:
		offsets.append((p - center) * 0.55)
	# 入ってくる向き: 画面の左右か下(背景の奥)から、出てくる地点のほうへ
	var start : Vector2
	match randi() % 3:
		0: start = Vector2(area.position.x - 100.0, center.y + randf_range(-60.0, 160.0))
		1: start = Vector2(area.end.x + 100.0, center.y + randf_range(-60.0, 160.0))
		_: start = Vector2(center.x + randf_range(-160.0, 160.0), area.end.y + 100.0)
	var group := _make_group(texture, offsets, unit_scale * 0.45, start, (center - start).angle(), orbit_speed * 1.6, true)
	group["center"] = center
	group["points"] = points
	group["end"] = seconds
	group["dir"] = -1.0 if randf() < 0.5 else 1.0 # 旋回の向き
	_groups.append(group)
	_place(group, 1.0)

## 静かなあいだに預かった影の知らせを、残りの時間で出す
func _release_pending() -> void:
	for info in _pending:
		var left : float = info["seconds"] - (_time - info["at"])
		foreshadow(info["texture"], info["points"], left, info["scale"])
	_pending.clear()

## 影の編隊: 端から入る → 出てくる地点のまわりを隊列のまま旋回 → 最後にその地点へ降りて、敵の並びにほどける
func _update_shadow(group : Dictionary, delta : float) -> void:
	var center : Vector2 = group["center"]
	var pos : Vector2 = group["pos"]
	var age : float = group["age"]
	var end : float = group["end"]
	var land := 1.3 # 最後に降りてくる時間
	var to_center := center - pos
	var dist := to_center.length()
	var target_angle : float
	var speed : float
	if age >= end - land:
		# 降りてくる: 地点へ向かって、ゆっくりになる
		target_angle = to_center.angle()
		speed = lerpf(orbit_speed, 30.0, clampf((age - (end - land)) / land, 0.0, 1.0))
	elif dist > orbit_radius * 1.6:
		# 入ってくる: 地点へまっすぐ
		target_angle = to_center.angle()
		speed = orbit_speed * 1.6
	else:
		# 旋回して待つ: 円の少し先を目指して回る(半径が合うように、内・外へ寄せる)
		var dir : float = group["dir"]
		var around := (-to_center).normalized()
		var ahead := center + around.rotated(dir * 0.7) * orbit_radius
		target_angle = (ahead - pos).angle()
		speed = orbit_speed
	group["angle"] = lerp_angle(group["angle"], target_angle, minf(delta * 3.0, 1.0))
	group["speed"] = move_toward(group["speed"], speed, delta * 200.0)
	group["pos"] = pos + Vector2.from_angle(group["angle"]) * group["speed"] * delta
	_place(group, 1.0)
	# 降りてくるあいだは、隊列を、敵が出てくる本当の並びへほどいていく
	if age >= end - land:
		var w := clampf((age - (end - land)) / land, 0.0, 1.0)
		w = w * w
		var points : Array[Vector2] = group["points"]
		var units : Array = group["units"]
		for i in units.size():
			var node : Sprite2D = units[i]["node"]
			node.position = node.position.lerp(points[i], w)

## 進む向き vel に機首を向けたときの回転。絵の機首は、ふつうは下向き(+y)。上向きの絵(MG)は逆にする
static func facing(texture : Texture2D, vel : Vector2) -> float:
	var nose_up := texture != null and texture.resource_path.get_file().begins_with("MG_")
	return vel.angle() + (PI * 0.5 if nose_up else -PI * 0.5)
