extends RefCounted
class_name IgniteGauge
## イグナイトゲージのロジック。Player や UI を知らず、変化をシグナルで通知するだけ。
## Lv0 からスタートし、Lv n に到達するのに n × graze_per_level 必要。
## (Lv1:10 〜 Lv10:100 / 累計550)

signal level_changed(level : int)
## 現在レベル内の進捗(0.0〜1.0)
signal progress_changed(ratio : float)

const MIN_LEVEL : int = 0
const MAX_LEVEL : int = 10

## Lv1 に到達するのに必要なグレイズ量(Lv n は n 倍)
var graze_per_level : float = 10.0
## 周囲の弾が1発増えるごとの加算ボーナス(密度が高いほど貯まりやすい)
var density_bonus : float = 0.05
## 発動時の無敵時間 = レベル × この値(Lv1:0.5s / Lv6:3.0s / Lv10:5.0s)
var invincible_seconds_per_level : float = 0.5
## レベルごとに秒数を直接指定する(Lv1, Lv2, ... の順)。空なら上の式を使う。
## 要素が足りないレベルは、上の式で補う
var custom_durations : Array[float] = []

var level : int = MIN_LEVEL
var _progress : float = 0.0

## 次のレベルに上がるのに必要な量
func required_for_next() -> float:
	return (level + 1) * graze_per_level

func ratio() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	return clampf(_progress / required_for_next(), 0.0, 1.0)

func can_ignite() -> bool:
	return level >= 1

func invincible_time(for_level : int) -> float:
	if for_level >= 1 and for_level <= custom_durations.size():
		return custom_durations[for_level - 1]
	return for_level * invincible_seconds_per_level

## グレイズ1回分を加算する。density は GrazeArea 内の弾数(自分を含む)
func add_graze(density : int = 1) -> void:
	if level >= MAX_LEVEL:
		return
	_progress += 1.0 + density_bonus * maxi(density - 1, 0)
	var leveled := false
	while level < MAX_LEVEL and _progress >= required_for_next():
		_progress -= required_for_next()
		level += 1
		leveled = true
	if level >= MAX_LEVEL:
		_progress = 0.0
	if leveled:
		level_changed.emit(level)
	progress_changed.emit(ratio())

## 被弾時: レベルを半分(端数切り捨て)にして進捗をリセット
func on_miss() -> void:
	var new_level := maxi(MIN_LEVEL, level / 2)
	var changed := new_level != level
	level = new_level
	_progress = 0.0
	if changed:
		level_changed.emit(level)
	progress_changed.emit(ratio())

## イグナイト発動時に呼ぶ。消費前のレベルを返し、レベルを0に戻す
func consume() -> int:
	var used := level
	level = MIN_LEVEL
	_progress = 0.0
	level_changed.emit(level)
	progress_changed.emit(ratio())
	return used
