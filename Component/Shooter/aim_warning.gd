extends Node2D
class_name AimWarning
## 撃つ前の予告線。EnemyShooter が、ShotPattern の Warning Time のあいだだけ出す(自分で置く必要はない)。
## 砲口から、弾の飛ぶ向き(自機を狙う向き)へ線を引き、撃つ瞬間まで自機を追う。
## はじめは薄く、撃つ時が近づくほど濃く、速く点滅する。

## 線の色(自機狙い弾 E_Magenta_Aim に合わせる)
const COLOR := Color(1.0, 0.35, 0.85)
## 線の長さ(px)。画面の外まで届く長さ
const LENGTH := 1400.0
## 線の太さ(芯)と、まわりの光の太さ
const WIDTH := 2.0
const GLOW_WIDTH := 8.0
## 同時に引く線の最大数(弾の向きが多い弾幕では、真ん中の1本だけにする)
const MAX_LINES := 5

var _shooter : EnemyShooter
var _pattern : ShotPattern
var _generation : int
var _duration : float = 1.0
var _elapsed : float = 0.0

func setup(shooter : EnemyShooter, pattern : ShotPattern, generation : int, duration : float) -> void:
	_shooter = shooter
	_pattern = pattern
	_generation = generation
	_duration = maxf(duration, 0.01)

func _ready() -> void:
	top_level = true # 戦車が回っても、線は画面の座標で引く
	z_as_relative = false
	z_index = 4 # 敵弾(5)のすぐ下
	global_position = Vector2.ZERO
	global_rotation = 0.0

func _process(delta : float) -> void:
	_elapsed += delta
	# 弾幕が切り替わった(ボスの段階が変わった)・撃てなくなったら消す
	if not is_instance_valid(_shooter) or _shooter._generation != _generation or not _shooter.enabled:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_shooter) or EnemyShooter.is_holding_fire():
		return
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	# 撃つ時が近づくほど、濃く、速く点滅する
	var blink := 0.65 + 0.35 * sin(_elapsed * lerpf(8.0, 32.0, t))
	var alpha := lerpf(0.4, 1.0, t) * blink
	var origin := _shooter.global_position
	for shot in _directions():
		var turn := deg_to_rad(_shooter.turn_degrees)
		var start : Vector2 = origin + (shot["offset"] as Vector2).rotated(turn)
		var end : Vector2 = start + Vector2.from_angle(shot["angle"] + turn) * LENGTH
		draw_line(start, end, Color(COLOR, alpha * 0.4), GLOW_WIDTH)
		draw_line(start, end, Color(COLOR.lightened(0.5), alpha), WIDTH)

## 弾の飛ぶ向き(撃つ弾と同じ計算)。同じ向きに重なる弾(列弾)は1本にまとめる
func _directions() -> Array[Dictionary]:
	var result : Array[Dictionary] = []
	var seen := {}
	var shots := ShotMath.bullets(_pattern, 0, _shooter._aim_angle(), _shooter._is_mirrored())
	for shot in shots:
		var key := snappedf(shot["angle"], 0.01)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(shot)
	if result.size() > MAX_LINES:
		# 多すぎるときは、狙いの向きに一番近い1本だけ
		var aim := _shooter._aim_angle()
		result.sort_custom(func(a, b) -> bool:
			return absf(angle_difference(a["angle"], aim)) < absf(angle_difference(b["angle"], aim)))
		result.resize(1)
	return result
