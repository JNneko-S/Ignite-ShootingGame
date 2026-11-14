extends RefCounted
class_name DifficultyTuning
## 難易度で、弾幕を自動で調整する。作ってある弾幕(.tres)は HARD の弾幕として、そのまま使う。
## NORMAL と EASY では、撃つ直前に、弾幕の写しを作って、数や速さを変える(元の .tres は変えない)。
##   HARD   … そのまま
##   NORMAL … 弾の数を少しだけ減らす(多い扇・輪・列弾・連射だけ)。間を少しあける
##   EASY   … 弾の数を大きく減らし、遅くし、ばらつきを減らして、見て分かりやすくする。間を広くあける。
##            雑魚の弾は、ボス(中ボス・援護を含む)の弾より、さらに遅くする
## 弾幕ごとの例外:
##   ShotPattern の Min Difficulty … この難易度より下では撃たない(その弾幕を消す)
##   ShotPattern の Skip Auto Tuning … 自動の調整をしない(EASY 用に作った弾幕など)
##   ShotPattern の Normal Version / Easy Version … その難易度のときは、手で作った別の弾幕に差し替える
##   ShooterPhase / EnemyShooter の Easy Patterns … EASY のときだけ、別の弾幕に差し替える
## 1つの砲口が、いくつもの弾幕を同時に撃つ(Patterns に2つ以上ある)ときは、前から MAX_LAYERS 個までにする
## (HARD は全部、NORMAL は2つまで、EASY は1つまで。いちばん上の弾幕が、その砲口の主な弾幕)
## 難易度は GameManager が、ステージが始まるときに level へ入れる。GameManager がない場面(プレビューなど)は HARD。

enum { EASY, NORMAL, HARD }

static var level : int = HARD

## 同時に撃つ弾幕の数の上限(EASY, NORMAL, HARD の順。0 なら上限なし)
const MAX_LAYERS : Array[int] = [1, 2, 0]

## EASY の弾の速さの倍率(ボスと、雑魚)
const EASY_SPEED_BOSS := 0.8
const EASY_SPEED_ZAKO := 0.65

static var _cache : Dictionary = {}

## 同時に撃つ弾幕のうち、この難易度で撃つもの(前から上限の数まで)
static func layers(list : Array[ShotPattern]) -> Array[ShotPattern]:
	var cap : int = MAX_LAYERS[clampi(level, 0, MAX_LAYERS.size() - 1)]
	if cap <= 0 or list.size() <= cap:
		return list
	return list.slice(0, cap)

static func is_easy() -> bool:
	return level == EASY

## この難易度で、pattern を撃つか(Min Difficulty より下なら撃たない)
static func allows(pattern : ShotPattern) -> bool:
	return pattern != null and level >= pattern.min_difficulty

## この難易度用に調整した pattern(HARD や、調整しない弾幕なら、そのまま)
## zako: 雑魚の弾か(EASY で、さらに遅くする)
static func tune(pattern : ShotPattern, zako : bool = false) -> ShotPattern:
	if pattern == null or level >= HARD or pattern.has_meta("difficulty_tuned"):
		return pattern
	# 手で作った、難易度ごとの弾幕があれば、それを使う
	if level == NORMAL and pattern.normal_version:
		return pattern.normal_version
	if level == EASY:
		if pattern.easy_version:
			return pattern.easy_version
		if pattern.normal_version:
			pattern = pattern.normal_version # NORMAL 用を元に、EASY 用に調整する
	if pattern.skip_auto_tuning:
		return pattern
	var key := "%d:%d:%d" % [pattern.get_instance_id(), level, int(zako)]
	if _cache.has(key):
		return _cache[key]
	var tuned := _make(pattern, level, zako)
	_cache[key] = tuned
	return tuned

static func _make(source : ShotPattern, lvl : int, zako : bool = false) -> ShotPattern:
	var p := source.duplicate(false) as ShotPattern
	p.set_meta("difficulty_tuned", lvl)
	var speed := 1.0
	if lvl == NORMAL:
		if p.bullet_count >= 6:
			p.bullet_count = maxi(roundi(p.bullet_count * 0.8), 5)
		if p.line_count >= 4:
			p.line_count -= 1
		if p.shot_count >= 8:
			p.shot_count = roundi(p.shot_count * 0.85)
		p.pause *= 1.1
	else: # EASY
		if p.bullet_count >= 6:
			p.bullet_count = maxi(roundi(p.bullet_count * 0.45), 4)
		elif p.bullet_count >= 4:
			p.bullet_count -= 1
		if p.line_count >= 2:
			p.line_count = ceili(p.line_count * 0.5)
		if p.shot_count >= 4:
			p.shot_count = maxi(roundi(p.shot_count * 0.5), 2)
			p.interval *= 1.25
		else:
			p.interval *= 1.5 # 休みなく撃ち続ける弾幕(Pause が 0 の流し撃ちなど)も、間をあける
		p.pause *= 1.6
		p.random_angle *= 0.5
		p.random_speed_ratio *= 0.5
		speed = EASY_SPEED_ZAKO if zako else EASY_SPEED_BOSS
	if speed != 1.0:
		p.bullet_speed *= speed
		p.bullet_accel *= speed
		var steps : Array[BulletStep] = []
		for step in p.motion:
			if step == null:
				steps.append(step)
				continue
			var s := step.duplicate(false) as BulletStep
			s.target_speed *= speed
			steps.append(s)
		p.motion = steps
	# 割れたあとの弾幕も、同じように調整する
	if p.split_pattern and not p.split_pattern.skip_auto_tuning:
		p.split_pattern = _make(p.split_pattern, lvl, zako)
	return p
