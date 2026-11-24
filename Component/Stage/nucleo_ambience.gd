extends Node2D
class_name NucleoAmbience
## 最終面(ヌクレオ)の空気: 舞い上がる火の粉、画面の下から脈打つ炉の熱の光、ときどき画面の端で機械がバチッと光る。
## ステージのシーンに置く。ステージの時間(StageRunner.stage_time)が Start Time を過ぎたら始まり、
## Peak Time(ラスボスの前)に向かって強くなる。弾の見やすさを優先して、どれも弾より奥・薄めに描く。

## 始まる時間と、いちばん強くなる時間(ステージの秒)
@export var start_time : float = 106.0
@export var peak_time : float = 210.0
## 強さが最大のときの、1秒に出す火の粉の数
@export var embers_per_second : float = 26.0
## 炉の熱の光の濃さ(最大)
@export var heat_alpha : float = 0.16
## 機械が光る間隔(秒、ばらつきの範囲)
@export var flash_interval : Vector2 = Vector2(2.5, 6.0)

const MAX_EMBERS : int = 260
const EMBER_HOT := Color(1.0, 0.75, 0.3)
const EMBER_COOL := Color(1.0, 0.3, 0.08)
const HEAT := Color(1.0, 0.28, 0.08)

var _runner : StageRunner
var _embers : Array[Dictionary] = [] # {p, v, life, max, size, phase}
var _spawn_acc : float = 0.0
var _flash_in : float = 3.0
var _flashes : Array[Dictionary] = [] # {p, life, max, size}
var _time : float = 0.0
var _intensity : float = 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = 0 # 背景より手前、敵・弾より奥
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _process(delta : float) -> void:
	_time += delta
	if _runner == null:
		_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	var stage_time := _runner.stage_time if _runner else 0.0
	var target := 0.0
	if stage_time >= start_time:
		target = lerpf(0.35, 1.0, clampf((stage_time - start_time) / maxf(peak_time - start_time, 1.0), 0.0, 1.0))
	_intensity = move_toward(_intensity, target, delta * 0.5)
	var view := CameraView.visible_rect(self)
	# 火の粉: 画面の下のほうから生まれて、ゆらぎながら上へ昇り、消える
	if _intensity > 0.0:
		_spawn_acc += embers_per_second * _intensity * delta
		while _spawn_acc >= 1.0 and _embers.size() < MAX_EMBERS:
			_spawn_acc -= 1.0
			var life := randf_range(1.6, 3.4)
			_embers.append({
				"p": Vector2(randf_range(view.position.x, view.end.x), view.end.y - randf_range(-10.0, view.size.y * 0.55)),
				"v": Vector2(randf_range(-12.0, 12.0), -randf_range(28.0, 70.0)),
				"life": life, "max": life, "size": randf_range(0.8, 2.0), "phase": randf() * TAU})
		_spawn_acc = minf(_spawn_acc, 4.0)
	for e in _embers:
		e["life"] -= delta
		var p : Vector2 = e["p"]
		var v : Vector2 = e["v"]
		p += (v + Vector2(sin(_time * 2.2 + e["phase"]) * 14.0, 0.0)) * delta
		e["p"] = p
	_embers = _embers.filter(func(e) -> bool: return e["life"] > 0.0)
	# 機械がバチッと光る(画面の左右の端の近く)
	if _intensity > 0.0:
		_flash_in -= delta
		if _flash_in <= 0.0:
			_flash_in = randf_range(flash_interval.x, flash_interval.y) / maxf(_intensity, 0.3)
			var side := -1.0 if randf() < 0.5 else 1.0
			var at := Vector2(view.get_center().x + side * view.size.x * randf_range(0.36, 0.48),
					randf_range(view.position.y + view.size.y * 0.1, view.end.y - view.size.y * 0.2))
			_flashes.append({"p": at, "life": 0.35, "max": 0.35, "size": randf_range(14.0, 26.0)})
			RailSparks.emit(get_tree(), at, Vector2(-side * 180.0, -120.0), 6, 90.0)
	for f in _flashes:
		f["life"] -= delta
	_flashes = _flashes.filter(func(f) -> bool: return f["life"] > 0.0)
	queue_redraw()

func _draw() -> void:
	if _intensity <= 0.0 and _embers.is_empty():
		return
	var view := CameraView.visible_rect(self)
	# 炉の熱: 画面の下から上へ薄くなる赤い光が、ゆっくり脈打つ
	var pulse := 0.7 + 0.3 * sin(_time * 1.7)
	var bands := 10
	var height := view.size.y * 0.45
	for i in bands:
		var t := float(i) / bands
		var a := heat_alpha * _intensity * pulse * (1.0 - t) * (1.0 - t)
		var y := view.end.y - height * (t + 1.0 / bands)
		draw_rect(Rect2(view.position.x, y, view.size.x, height / bands + 1.0), Color(HEAT, a))
	# 火の粉
	for e in _embers:
		var k : float = e["life"] / e["max"]
		var c := EMBER_COOL.lerp(EMBER_HOT, k)
		c.a = minf(k * 1.6, 1.0) * 0.85
		draw_circle(e["p"], e["size"], c)
	# 機械の光
	for f in _flashes:
		var k : float = f["life"] / f["max"]
		draw_circle(f["p"], f["size"] * (1.4 - k * 0.4), Color(1.0, 0.55, 0.2, 0.25 * k))
		draw_circle(f["p"], f["size"] * 0.3 * k, Color(1.0, 0.95, 0.8, 0.9 * k))
