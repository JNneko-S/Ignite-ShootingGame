extends BossState
class_name CrossFireState
## 翼の両方の大砲から CrossFire を撃つステート。ほかの弾幕とは一緒に撃たない(入ったときに全ての砲口を止める)。
##
## CrossFire: 多方向への高速弾を、切れ目なく連射し続ける。弾はまっすぐ飛ぶので、画面に何本もの直線ができる。
## Shift Interval(2秒)ごとに、発射の角度が少しずつ変わり、直線の位置がずれる。
## 自機は、ずれるたびに、直線のすき間へ移り直すことになる(自機を揺らす)。
##
## ずらす向き:
##   決まった向き … 同じ向きへ少しずつずらし、端まで行ったら逆へ(第一形態の前半)
##   自機で決める … 自機が画面のどちら側にいるかで、ずらす向きとタイミングが変わる
##                  (1回の後半(Track After)と、Track From Phase 以降の段階はずっと):
##                  ・自機のいる側へずらす(直線が自機の方へ寄ってくる)
##                  ・自機が反対側へ移ると、次を待たずに少し早く(Track Reaction 秒後に)そちらへずらす
##
## 段階ごとの撃ち方:
##   第一形態           … CrossFire を1回
##   Aimed From Phase〜  … CrossFire → AimedCrossFire(自機狙い。両方の大砲の弾が自機で交わる)
##   Random From Phase〜 … Random Volleys 回続けて撃つ。1回ごとに CrossFire と AimedCrossFire をランダムに選ぶ
## 第一形態・第二形態は、撃つ前に画面の敵弾が消えるのを待つ(BossState の Wait Clear Before Phase)。
## 撃ち終わったら Next State へ移る。

## 撃つ砲口(翼の両方の大砲)
@export var shooters : Array[EnemyShooter] = []
@export var cross_fire : ShotPattern
@export var aimed_cross_fire : ShotPattern
## AimedCrossFire を使い始める段階(0 = 第一形態)
@export var aimed_from_phase : int = 1
## CrossFire と AimedCrossFire をランダムに切り替える段階
@export var random_from_phase : int = 2
## そのとき、続けて撃つ回数
@export var random_volleys : int = 4
## 1回撃ってから、次を撃つまでの間(秒)
@export var volley_gap : float = 0.8

@export_group("角度をずらす")
## 発射の角度を変える間隔(秒)
@export var shift_interval : float = 2.0
## 1回にずらす角度(度)。段階ごと(第一形態から)。足りなければ最後の値。
## 弾と弾の間の角度(CrossFire は 12°)の半分くらいだと、直線がちょうどすき間に来る
@export var shift_steps : Array[float] = [6.0, 10.0, 15.0]
## 正面から、これ以上はずらさない(度)。段階ごと
@export var shift_max : Array[float] = [30.0, 40.0, 50.0]
## ずらすのにかける時間(秒)。短いほど、直線がパッと切り替わる
@export var shift_time : float = 0.12

@export_group("自機で決める")
## この段階から、1回の最初から自機でずらす向きを決める(それより前の段階は、後半だけ)
@export var track_from_phase : int = 1
## 1回の、この割合から先は自機で決める(後半)
@export_range(0.0, 1.0, 0.05) var track_after : float = 0.5
## 自機が反対側へ移ったとき、この時間(秒)のあとにずらす(次の間隔を待たない)。段階ごと
@export var track_reaction : Array[float] = [0.8, 0.6, 0.4]
## 画面の真ん中から、これだけ離れたら「その側にいる」とみなす(px)
@export var track_margin : float = 16.0


func _init() -> void:
	hold_position = true # ワインダーの間は、ボスは動かない

func _run(token : int) -> void:
	if not running(token):
		return
	for volley in _plan():
		await wait_bullets_clear(token) # 第一・第二形態は、前の弾が消えてから撃つ
		if not running(token):
			return
		await _volley(token, volley)
		if not running(token):
			return
		stop_shooters(shooters)
		await wait(volley_gap)
		if not running(token):
			return
	finish(token)

## 今の段階で撃つ順番(ShotPattern の並び)
func _plan() -> Array[ShotPattern]:
	var p := phase()
	var plan : Array[ShotPattern] = []
	if p >= random_from_phase:
		for i in maxi(random_volleys, 1):
			plan.append(aimed_cross_fire if aimed_cross_fire != null and randf() < 0.5 else cross_fire)
	elif p >= aimed_from_phase:
		plan.append(cross_fire)
		plan.append(aimed_cross_fire)
	else:
		plan.append(cross_fire)
	var result : Array[ShotPattern] = []
	for pattern in plan:
		if pattern != null:
			result.append(pattern)
	return result

## 両方の大砲から pattern を1回撃つ。CrossFire なら、Shift Interval ごとに発射の角度を少しずつずらす
func _volley(token : int, pattern : ShotPattern) -> void:
	var length := _length(pattern)
	_set_turn(0.0)
	for shooter in shooters:
		if is_instance_valid(shooter) and shooter.enabled:
			shooter.set_patterns([pattern])
	if pattern != cross_fire:
		await wait(length)
		return
	var p := phase()
	var step : float = _at(shift_steps, p)
	var limit : float = _at(shift_max, p)
	var reaction : float = _at(track_reaction, p)
	var rate := step / maxf(shift_time, 0.01) # 度/秒
	var turn := 0.0
	var target := 0.0
	var direction := 1.0 if randf() < 0.5 else -1.0
	var seen_side := _player_side()
	var timer := 0.0
	var elapsed := 0.0
	while elapsed < length and running(token):
		# 1フレームずつ進める(ポーズ中は進めない)
		await get_tree().physics_frame
		if get_tree().paused:
			continue
		var dt := get_physics_process_delta_time()
		elapsed += dt
		timer += dt
		var tracking := p >= track_from_phase or elapsed >= length * track_after
		if tracking:
			var side := _player_side()
			if side != 0.0 and side != seen_side:
				# 自機が反対側へ移った: 次の間隔を待たず、少し早くずらす
				seen_side = side
				timer = maxf(timer, shift_interval - reaction)
		if timer >= shift_interval:
			timer = 0.0
			if tracking and seen_side != 0.0:
				direction = seen_side # 自機のいる側へずらす
			if absf(target + direction * step) > limit + 0.01:
				direction = -direction # 端まで行ったら逆へ
			target = clampf(target + direction * step, -limit, limit)
		turn = move_toward(turn, target, rate * dt)
		_set_turn(turn)

## 自機が画面のどちら側にいるか。発射の向きの符号で返す(左 = +1、右 = -1、真ん中 = 0)
func _player_side() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or boss == null:
		return 0.0
	var center := CameraView.visible_rect(boss).get_center().x
	var dx := player.global_position.x - center
	if absf(dx) < track_margin:
		return 0.0
	return 1.0 if dx < 0.0 else -1.0

func _set_turn(degrees : float) -> void:
	for shooter in shooters:
		if is_instance_valid(shooter):
			shooter.turn_degrees = degrees

func _at(values : Array[float], index : int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(index, 0, values.size() - 1)]

## 1回撃ち終わるまでの時間(秒): 撃つ前の待ち(予告線があればその長さ)+ 連射の長さ
func _length(pattern : ShotPattern) -> float:
	var before := maxf(pattern.start_delay, pattern.warning_time)
	return before + pattern.interval * maxi(pattern.shot_count, 1)
