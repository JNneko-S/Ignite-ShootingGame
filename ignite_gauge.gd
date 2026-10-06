extends RefCounted
class_name IgniteGauge
## イグナイトゲージのロジック。Player や UI を知らず、変化をシグナルで通知するだけ。
## レベル n に上がるのに必要なグレイズ量 = n × graze_per_level
## (10段階・10刻みなら累計 550 でLv10)

signal level_changed(level : int)
## 現在レベル内の進捗(0.0〜1.0)
signal progress_changed(ratio : float)

const MIN_LEVEL : int = 1
const MAX_LEVEL : int = 10

## 1レベルあたりの基本必要量(Lv n → n+1 には n × この値)
var graze_per_level : float = 10.0
## 周囲の弾が1発増えるごとの加算ボーナス(密度が高いほど貯まりやすい)
var density_bonus : float = 0.05

var level : int = MIN_LEVEL
var _progress : float = 0.0

func required_for_next() -> float:
	return level * graze_per_level

func ratio() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	return clampf(_progress / required_for_next(), 0.0, 1.0)

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

## 被弾時: レベルを半分にして進捗をリセット
func on_miss() -> void:
	var new_level := maxi(MIN_LEVEL, level / 2)
	var changed := new_level != level
	level = new_level
	_progress = 0.0
	if changed:
		level_changed.emit(level)
	progress_changed.emit(ratio())

## イグナイト発動時に呼ぶ。消費前のレベルを返し、ゲージを初期状態に戻す
func consume() -> int:
	var used := level
	level = MIN_LEVEL
	_progress = 0.0
	level_changed.emit(level)
	progress_changed.emit(ratio())
	return used
