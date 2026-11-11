extends BossState
class_name CrossFireState
## 翼の両方の大砲から CrossFire を撃つステート。ほかの弾幕とは一緒に撃たない(入ったときに全ての砲口を止める)。
##
## 段階ごとの撃ち方:
##   第一形態          … CrossFire を1回(正面へ)
##   Aimed From Phase〜 … CrossFire(正面へ) → AimedCrossFire(自機狙い。両方の大砲の弾が自機で交わる)
##   Random From Phase〜 … Random Volleys 回続けて撃つ。1回ごとに CrossFire と AimedCrossFire をランダムに選ぶ。
##                        CrossFire は正面へ撃ち始め、途中で左右のどちらかへ向きを変える
## 撃ち終わったら Next State へ移る。

## 撃つ砲口(翼の両方の大砲)
@export var shooters : Array[EnemyShooter] = []
@export var cross_fire : ShotPattern
@export var aimed_cross_fire : ShotPattern
## AimedCrossFire を使い始める段階(0 = 第一形態)
@export var aimed_from_phase : int = 1
## CrossFire と AimedCrossFire をランダムに切り替え、CrossFire の向きを振る段階
@export var random_from_phase : int = 2
## そのとき、続けて撃つ回数
@export var random_volleys : int = 4
## 1回撃ってから、次を撃つまでの間(秒)
@export var volley_gap : float = 0.8

@export_group("向きを振る")
## CrossFire を左右へ向けるときの角度(度)
@export var side_angle : float = 30.0
## 撃ち始めてから、向きを変え始めるまで(1回の長さに対する割合)
@export_range(0.0, 1.0, 0.05) var turn_at : float = 0.4
## 向きを変えるのにかける時間(秒)
@export var turn_time : float = 0.35

func _run(token : int) -> void:
	if not running(token):
		return
	for volley in _plan():
		await _volley(token, volley["pattern"], volley["swing"])
		if not running(token):
			return
		await wait(volley_gap)
		if not running(token):
			return
	finish(token)

## 今の段階で撃つ順番。{"pattern": ShotPattern, "swing": 向きを振るか} の並び
func _plan() -> Array[Dictionary]:
	var p := phase()
	var plan : Array[Dictionary] = []
	if p >= random_from_phase:
		for i in maxi(random_volleys, 1):
			var aimed := aimed_cross_fire != null and randf() < 0.5
			plan.append({"pattern": aimed_cross_fire if aimed else cross_fire, "swing": not aimed})
	elif p >= aimed_from_phase:
		plan.append({"pattern": cross_fire, "swing": false})
		plan.append({"pattern": aimed_cross_fire, "swing": false})
	else:
		plan.append({"pattern": cross_fire, "swing": false})
	var result : Array[Dictionary] = []
	for volley in plan:
		if volley["pattern"] != null:
			result.append(volley)
	return result

## 両方の大砲から pattern を1回撃つ。swing なら、途中で左右のどちらかへ向きを変える
func _volley(token : int, pattern : ShotPattern, swing : bool) -> void:
	var length := _length(pattern)
	for shooter in shooters:
		if is_instance_valid(shooter) and shooter.enabled:
			shooter.turn_degrees = 0.0
			shooter.set_patterns([pattern])
	if not swing:
		await wait(length)
		return
	await wait(length * turn_at)
	if not running(token):
		return
	var to := side_angle * (1.0 if randf() < 0.5 else -1.0) # 左右のどちらか
	var tween := create_tween()
	tween.tween_method(_set_turn, 0.0, to, turn_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await wait(length * (1.0 - turn_at))

func _set_turn(degrees : float) -> void:
	for shooter in shooters:
		if is_instance_valid(shooter):
			shooter.turn_degrees = degrees

## 1回撃ち終わるまでの時間(秒): 撃つ前の待ち(予告線があればその長さ)+ 連射の長さ
func _length(pattern : ShotPattern) -> float:
	var before := maxf(pattern.start_delay, pattern.warning_time)
	return before + pattern.interval * maxi(pattern.shot_count, 1)
