@tool
extends RefCounted
class_name ShotMath
## ShotPattern の弾の撃ち方と動きを計算する。
## ゲーム(EnemyShooter / EnemyBullet)とエディタのプレビュー(ShotPreview / StagePreview)が、
## 同じ関数を使うので、プレビューと実際の弾幕が一致する。

## 1パターンあたりの発射回数の上限(無限ループ防止)
const MAX_SHOTS : int = 5000

# ---------------------------------------------------------------- 撃ち方

## 撃ち始めてから until 秒までの発射を、{"time": 発射時刻, "index": 何発目か} の並びで返す。
## 時刻は、撃ち始め(敵の出現)からの秒数。
## seconds_per_beat は、Timing Unit が BEATS のパターンで、1拍を何秒にするか
static func shot_times(pattern : ShotPattern, until : float, seconds_per_beat : float = 0.5) -> Array[Dictionary]:
	var shots : Array[Dictionary] = []
	var unit := time_unit(pattern, seconds_per_beat)
	var interval := pattern.interval * unit
	var t := pattern.start_delay * unit
	var index := 0
	while t <= until + 0.000001 and index < MAX_SHOTS:
		for i in maxi(pattern.shot_count, 1):
			var fire_time := t + interval * i
			if fire_time > until + 0.000001:
				return shots
			shots.append({"time": fire_time, "index": index})
			index += 1
		if not pattern.loop:
			return shots
		t += interval * maxi(pattern.shot_count, 1) + pattern.pause * unit
		if pattern.interval <= 0.0 and pattern.pause <= 0.0:
			return shots # 時間が進まない設定で、無限ループしないように
	return shots

## パターンのタイミングの1単位が何秒か(秒なら 1、拍なら seconds_per_beat)
static func time_unit(pattern : ShotPattern, seconds_per_beat : float) -> float:
	return seconds_per_beat if pattern.timing_unit == ShotPattern.TimingUnit.BEATS else 1.0

## shot_index 回目の発射で出る、全ての弾。
## 1発ごとに {"angle": 向き(ラジアン), "speed_scale": 速さの倍率, "offset": 砲口からの出現位置} を返す。
## aim_angle は、砲口から自機への角度(aim_at_player のときだけ使う)
static func bullets(pattern : ShotPattern, shot_index : int, aim_angle : float) -> Array[Dictionary]:
	var base := aim_angle if pattern.aim_at_player else Vector2.DOWN.angle()
	base += deg_to_rad(pattern.base_angle + rotation_degrees(pattern, shot_index))
	var count := maxi(pattern.bullet_count, 1)
	var lines := maxi(pattern.line_count, 1)
	var is_ring := pattern.spread_angle >= 360.0
	var has_random := pattern.random_angle > 0.0 or pattern.random_speed_ratio > 0.0
	var result : Array[Dictionary] = []
	for i in count:
		var spread := 0.0
		if count > 1:
			if is_ring:
				spread = 360.0 * i / count
			else:
				spread = -pattern.spread_angle / 2.0 + pattern.spread_angle * i / (count - 1)
		for line in lines:
			var angle := base + deg_to_rad(spread)
			var speed_scale := 1.0 + pattern.line_speed_ratio * line
			if has_random:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([pattern.random_seed, shot_index, i, line])
				angle += deg_to_rad(rng.randf_range(-pattern.random_angle, pattern.random_angle))
				speed_scale *= 1.0 + rng.randf_range(-pattern.random_speed_ratio, pattern.random_speed_ratio)
			result.append({
				"angle": angle,
				"speed_scale": speed_scale,
				"offset": Vector2.from_angle(angle) * pattern.spawn_radius})
	return result

## shot_index 回目の発射での、基準角度の回転量(度)。渦巻き・反転・回転の加速・揺れを合わせたもの
static func rotation_degrees(pattern : ShotPattern, shot_index : int) -> float:
	var k := float(rotation_steps(pattern, shot_index))
	var degrees := pattern.rotate_per_shot * k + 0.5 * pattern.rotate_accel * k * k
	if pattern.angle_wave_amplitude != 0.0 and pattern.angle_wave_shots > 0:
		degrees += pattern.angle_wave_amplitude * sin(TAU * shot_index / pattern.angle_wave_shots)
	return degrees

static func rotation_steps(pattern : ShotPattern, shot_index : int) -> int:
	var n := pattern.reverse_every_shots
	if n <= 0:
		return shot_index
	var k := shot_index % (n * 2)
	return k if k < n else n * 2 - k

# ---------------------------------------------------------------- 弾の動き

## 区間の始めに、向きを変える
static func turned_heading(step : BulletStep, heading : float, position : Vector2, player : Vector2) -> float:
	match step.turn_mode:
		BulletStep.TurnMode.ADD:
			return heading + deg_to_rad(step.turn_angle)
		BulletStep.TurnMode.AIM_PLAYER:
			return (player - position).angle() + deg_to_rad(step.turn_angle)
		BulletStep.TurnMode.ABSOLUTE:
			return Vector2.DOWN.angle() + deg_to_rad(step.turn_angle)
	return heading

## 区間の始めから t 秒後の速さ(速さの倍率をかける前)
static func step_speed(step : BulletStep, from_speed : float, t : float) -> float:
	if not step.change_speed:
		return from_speed
	if step.duration <= 0.0 or t >= step.duration:
		return step.target_speed
	return Tween.interpolate_value(from_speed, step.target_speed - from_speed, t, step.duration, step.speed_trans, step.speed_ease)

## プレビュー用に、Motion の各区間の軌跡を前もって計算する(ゲームの物理フレームと同じ刻み)。
## 区間の始めの向きを 0、速さの倍率を 1 とした、区間内の移動量の表。Motion が空なら空
static func motion_table(pattern : ShotPattern) -> Array[Dictionary]:
	var table : Array[Dictionary] = []
	var dt := 1.0 / Engine.physics_ticks_per_second
	var speed := pattern.bullet_speed
	for step in pattern.motion:
		if step == null:
			continue
		var points := PackedVector2Array([Vector2.ZERO])
		var position := Vector2.ZERO
		var heading := 0.0
		var ticks := ceili(maxf(step.duration, 0.0) / dt - 0.0001)
		for i in range(1, ticks + 1):
			var current := step_speed(step, speed, minf(i * dt, step.duration))
			heading += deg_to_rad(step.angular_velocity) * dt
			position += Vector2.from_angle(heading) * current * dt
			points.append(position)
		speed = step_speed(step, speed, step.duration)
		table.append({"step": step, "points": points, "duration": ticks * dt,
				"end_heading": heading, "end_speed": speed})
	return table

## 撃ってから age 秒後の弾の位置。origin は弾の出現位置(砲口 + offset)、table は motion_table の結果
static func bullet_position(pattern : ShotPattern, table : Array[Dictionary], angle : float, speed_scale : float,
		age : float, origin : Vector2, player : Vector2) -> Vector2:
	if table.is_empty():
		return origin + Vector2.from_angle(angle) * distance(pattern, age) * speed_scale
	var dt := 1.0 / Engine.physics_ticks_per_second
	var position := origin
	var heading := angle
	var remaining := age
	var speed := pattern.bullet_speed
	for entry in table:
		heading = turned_heading(entry["step"], heading, position, player)
		var points : PackedVector2Array = entry["points"]
		var duration : float = entry["duration"]
		var f := clampf(minf(remaining, duration) / dt, 0.0, points.size() - 1.0)
		var i := mini(int(f), points.size() - 2)
		var local := points[0] if points.size() < 2 else points[i].lerp(points[i + 1], f - i)
		position += local.rotated(heading) * speed_scale
		if remaining <= duration:
			return position
		heading += entry["end_heading"]
		speed = entry["end_speed"]
		remaining -= duration
	# 最後の区間のあとは、まっすぐ飛ぶ
	return position + Vector2.from_angle(heading) * speed * speed_scale * remaining

## Motion がないときの、撃ってから age 秒後の砲口からの距離(加速度で止まったら、そこで止まる)
static func distance(pattern : ShotPattern, age : float) -> float:
	var v := pattern.bullet_speed
	var a := pattern.bullet_accel
	if a < 0.0:
		var stop := v / -a
		if age > stop:
			return v * stop + 0.5 * a * stop * stop
	return v * age + 0.5 * a * age * age
