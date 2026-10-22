extends RefCounted
class_name IgniteGauge
## イグナイトゲージ。体力を兼ねる。Player や UI を知らず、シグナルで通知するだけ。
## ゲージは 0〜最大値 の連続値で、レベル(Lv0〜Lv5)は値から決まる。
##   Lv n に到達する値 = graze_per_level × (1 + 2 + ... + n)   例) 20, 60, 120, 200, 300
## グレイズで増え、イグナイトの発動では consume_levels() でレベルを消費する(途中の端数は残る)。
## 被弾すると miss_penalty だけレベルが下がる。レベルの数 = 耐えられる被弾回数(Lv5なら5回耐える)。
## Lv0 で被弾する(下がった結果が0未満になる)と死亡(on_miss が true を返す)。

signal level_changed(level : int)
## 現在レベル内の進捗(0.0〜1.0)
signal progress_changed(ratio : float)

const MIN_LEVEL : int = 0
const MAX_LEVEL : int = 5

## Lv1 に到達するのに必要なグレイズ量(Lv n に上がるには n 倍)
var graze_per_level : float = 20.0
## 周囲の弾が1発増えるごとの加算ボーナス(密度が高いほど貯まりやすい)
var density_bonus : float = 0.05
## 開始・復活時のレベル(難易度で決まる)
var start_level : int = 0
## 被弾1回で減るレベル(難易度で決まる)
var miss_penalty : int = 1

var value : float = 0.0
var level : int = MIN_LEVEL
## イグナイトで消費したレベルの累計(被弾で減った分は含まない)
var levels_consumed_total : int = 0

## Lv n に到達するゲージの値
func threshold(for_level : int) -> float:
	return graze_per_level * for_level * (for_level + 1) / 2.0

func max_value() -> float:
	return threshold(MAX_LEVEL)

## 難易度の設定を反映して、開始レベルに戻す
func configure(new_start_level : int, new_miss_penalty : int) -> void:
	start_level = clampi(new_start_level, MIN_LEVEL, MAX_LEVEL)
	miss_penalty = maxi(new_miss_penalty, 1)
	reset_to_start()

func reset_to_start() -> void:
	value = threshold(start_level)
	_update(true)

## 現在レベル内の進捗(0.0〜1.0)
func ratio() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	var low := threshold(level)
	return clampf((value - low) / (threshold(level + 1) - low), 0.0, 1.0)

## グレイズ1回分を加算する。density は GrazeArea 内の弾数(自分を含む)
func add_graze(density : int = 1) -> void:
	value = minf(value + 1.0 + density_bonus * maxi(density - 1, 0), max_value())
	_update()

## イグナイトの発動でレベルを count 個消費する。実際に消費した数を返す。
## 途中の端数は残す(Lv3の40% を1つ消費すると、Lv2の40%)
func consume_levels(count : int) -> int:
	var n := clampi(count, 0, level)
	if n <= 0:
		return 0
	var fraction := 0.0
	if level < MAX_LEVEL:
		fraction = (value - threshold(level)) / (threshold(level + 1) - threshold(level))
	var new_level := level - n
	value = threshold(new_level) + fraction * (threshold(new_level + 1) - threshold(new_level))
	levels_consumed_total += n
	_update()
	return n

## ゲージを直接増やす(補給アイテムなど)。グレイズの加算とは別
func add_value(amount : float) -> void:
	value = minf(value + amount, max_value())
	_update()

## 被弾。レベルを miss_penalty 下げる。下げた結果が0未満なら死亡として true を返す(Lv0で被弾など)
## (死亡時のゲージのリセットは、復活時の reset_to_start で行う)
func on_miss() -> bool:
	var new_level := level - miss_penalty
	if new_level < 0:
		return true
	value = threshold(new_level)
	_update()
	return false

func _update(force : bool = false) -> void:
	var new_level := MIN_LEVEL
	for l in range(1, MAX_LEVEL + 1):
		if value >= threshold(l):
			new_level = l
	var changed := new_level != level
	level = new_level
	if changed or force:
		level_changed.emit(level)
	progress_changed.emit(ratio())
