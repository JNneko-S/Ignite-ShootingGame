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
## プレイヤーが選んだ難易度(EASY / NORMAL / HARD)。弾幕だけ一段上に扱うステージ(最終面)でも変わらない。
## 限定弾幕(ShotPattern の Max Difficulty が 3 より小さい弾幕)を撃つかどうかは、こちらで決める
static var chosen_level : int = HARD
## HARD を選んで、弾幕を一段上に扱うステージ(最終面)に来たときと、二周目で HARD の弾幕を撃つとき、true(GameManager が決める)。
## NORMAL も HARD の弾幕になるので、HARD はさらに撃つ間を詰めて速くし、NORMAL との差を残す
static var hard_plus : bool = false
const HARD_PLUS_RATE := 1.18
## 雑魚の撃つ間の倍率(ステージの Zako Fire Interval Scale。1 ならそのまま。GameManager が入れる)
static var zako_interval_scale : float = 1.0
const HARD_PLUS_SPEED := 1.06

## 同時に撃つ弾幕の数の上限(EASY, NORMAL, HARD の順。0 なら上限なし)
const MAX_LAYERS : Array[int] = [1, 2, 0]

## EASY の弾の速さの倍率(ボスと、雑魚)
const EASY_SPEED_BOSS := 0.8
const EASY_SPEED_ZAKO := 0.65

static var _cache : Dictionary = {}

## 同時に撃つ弾幕のうち、この難易度で撃つもの(前から上限の数まで)
## no_cap: オンなら、数を絞らない(限定弾幕の振り分けだけをする。二周目の弾幕・カウンター大技)
static func layers(list : Array[ShotPattern], no_cap : bool = false) -> Array[ShotPattern]:
	# 限定弾幕: この難易度で撃たない限定弾幕は、枠を使わない。撃つ限定弾幕が「差し替え」(Replaces Others)なら、それだけを撃つ
	var replacing : Array[ShotPattern] = []
	var kept : Array[ShotPattern] = []
	for p in list:
		if p and (p.max_difficulty < 3 or p.another_only):
			if not allows(p):
				continue
			if p.replaces_others:
				replacing.append(p)
		kept.append(p)
	list = replacing if not replacing.is_empty() else kept
	if no_cap:
		return list
	var cap : int = MAX_LAYERS[clampi(level, 0, MAX_LAYERS.size() - 1)]
	if cap <= 0 or list.size() <= cap:
		return list
	return list.slice(0, cap)

static func is_easy() -> bool:
	return level == EASY

## この難易度で、pattern を撃つか(Min Difficulty より下なら撃たない)
static func allows(pattern : ShotPattern) -> bool:
	if pattern == null:
		return false
	if pattern.another_only:
		return chosen() == 3 # ANOTHER 用の限定弾幕
	if pattern.max_difficulty < 3:
		# 限定弾幕: 選んだ難易度が Min 〜 Max のときだけ撃つ(ANOTHER は 3 として扱うので撃たない)
		var c := chosen()
		if c == 3 and pattern.also_another and pattern.max_difficulty == 2:
			return true # HARD 用の限定弾幕を、ANOTHER でも撃つ
		return c >= pattern.min_difficulty and c <= pattern.max_difficulty
	return level >= pattern.min_difficulty

## 選んだ難易度(ANOTHER なら 3)
static func chosen() -> int:
	return 3 if HazardRank.active else chosen_level

## この難易度用に調整した pattern(HARD や、調整しない弾幕なら、そのまま)
## zako: 雑魚の弾か(EASY で、さらに遅くする)
static func tune(pattern : ShotPattern, zako : bool = false) -> ShotPattern:
	if pattern == null or pattern.has_meta("difficulty_tuned"):
		return pattern
	if HazardRank.active:
		return _tune_another(pattern, zako)
	if zako and zako_interval_scale != 1.0:
		# 道中の弾が多いステージ: 雑魚の撃つ間をのばしてから、難易度の調整をする
		var key := "Z:%d:%d:%.2f:%d" % [pattern.get_instance_id(), level, zako_interval_scale, int(hard_plus)]
		if not _cache.has(key):
			var slow := pattern.duplicate(false) as ShotPattern
			slow.interval *= zako_interval_scale
			slow.pause *= zako_interval_scale
			slow.start_delay *= zako_interval_scale
			var tuned := _tune_level(slow, zako)
			if tuned == slow or tuned.resource_path == "":
				tuned.set_meta("difficulty_tuned", level) # 共有の .tres(Normal Version など)には印を付けない
			_cache[key] = tuned
		return _cache[key]
	return _tune_level(pattern, zako)

## 難易度(EASY / NORMAL / HARD)の調整だけをする
static func _tune_level(pattern : ShotPattern, zako : bool) -> ShotPattern:
	if level >= HARD:
		if hard_plus and not pattern.skip_auto_tuning:
			var key := "H+:%d:%d" % [pattern.get_instance_id(), int(zako)]
			if not _cache.has(key):
				var p := _scale_pattern(pattern, HARD_PLUS_RATE, HARD_PLUS_SPEED)
				p.set_meta("difficulty_tuned", HARD)
				_cache[key] = p
			return _cache[key]
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

## ANOTHER: HARD の弾幕を元に、ハザードランクの段階で強くする。
## 弾幕の段階(HazardRank.barrage_tier)に応じて、手で作った ANOTHER 用(Another Version)か、
## BLACK ANOTHER 用(Black Version。なければ ANOTHER 用)に差し替える。
## 撃つ頻度(間・休み・最初の待ちが短くなる)と、弾の速さが上がる。ボス・中ボスは頻度の上がり方を控えめにする
static func _tune_another(source : ShotPattern, zako : bool) -> ShotPattern:
	var pattern := source
	var tier := HazardRank.barrage_tier(not zako)
	if tier == HazardRank.Tier.BLACK and source.black_version:
		pattern = source.black_version
	elif tier >= HazardRank.Tier.ANOTHER and source.another_version:
		pattern = source.another_version
	var step := HazardRank.step()
	if step <= 0:
		return pattern
	var key := "A:%d:%d:%d:%.2f:%d" % [pattern.get_instance_id(), step, int(zako), HazardRank.zako_rate_ratio, int(HazardRank.stage_force_black)]
	if _cache.has(key):
		return _cache[key]
	var rate := HazardRank.fire_rate_scale(not zako)
	if pattern != source or pattern.another_made:
		# 手で作った ANOTHER 用の弾幕は、もともと濃いので、頻度はボスでは上げず、雑魚では上がり方を半分にする
		rate = 1.0 if not zako else 1.0 + (rate - 1.0) * 0.5
	var p := _scale_pattern(pattern, rate, HazardRank.bullet_speed_scale())
	p.set_meta("difficulty_tuned", HARD + step)
	_cache[key] = p
	return p

## 撃つ頻度を rate 倍、弾の速さを speed 倍にした写し(割れたあとの弾幕も、速さだけ同じように)
static func _scale_pattern(source : ShotPattern, rate : float, speed : float) -> ShotPattern:
	var p := source.duplicate(false) as ShotPattern
	if rate > 1.0:
		p.interval /= rate
		p.pause /= rate
		p.start_delay /= rate
	p.bullet_speed *= speed
	p.bullet_accel *= speed
	var steps : Array[BulletStep] = []
	for s in p.motion:
		if s == null:
			steps.append(s)
			continue
		var copy := s.duplicate(false) as BulletStep
		copy.target_speed *= speed
		copy.duration /= speed # 速くなったぶん、同じ距離で曲がる・止まる
		steps.append(copy)
	p.motion = steps
	if p.split_time > 0.0:
		p.split_time /= speed
	if p.split_pattern:
		p.split_pattern = _scale_pattern(p.split_pattern, 1.0, speed)
	return p

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
