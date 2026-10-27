extends Node2D
class_name EnemyShooter
## 敵に付ける弾発射コンポーネント。ShotPattern を複数登録でき、それぞれ独立して撃つ。
## このノードの位置が発射位置(砲口)になるので、敵の子として好きな位置に置く。
## 自機への狙い撃ちには、Player が "player" グループに入っている必要がある。
##
## ボスに BeatConductor があると、Patterns は使わず、譜面(BeatChart)のとおりに撃つ。

@export var patterns : Array[ShotPattern] = []
## ShotPattern 側で弾シーンが未指定のときに使う弾
@export var default_bullet_scene : PackedScene
## 弾の生成先。未設定なら現在のシーン直下
@export var bullet_parent : Node
## true なら、画面内にいる間だけ撃つ(画面外からの不意打ち・無駄撃ち防止)
@export var only_when_on_screen : bool = true
## true なら、発射のたびに使われている値をデバッグ出力に表示する(設定が効いているかの確認用)
@export var debug_log : bool = false

## false にすると撃たなくなる(壊れた部位の砲口など)。譜面で撃つときも撃たない
var enabled : bool = true

## この時刻(Time.get_ticks_msec)まで、全ての敵が撃たない(自機の復活直後など)
static var _hold_fire_until_msec : int = 0

## 全ての敵を、seconds 秒のあいだ撃たせない。すでにもっと長く止めていれば、そのまま
static func hold_fire(seconds : float) -> void:
	_hold_fire_until_msec = maxi(_hold_fire_until_msec, Time.get_ticks_msec() + int(seconds * 1000.0))

static func is_holding_fire() -> bool:
	return Time.get_ticks_msec() < _hold_fire_until_msec

## stop() で増える。動いている _run_pattern は、これが変わったら止まる
var _generation : int = 0
## aim_once_per_burst 用の、パターンごとのバーストの向き(譜面で撃つとき)
var _burst_aims : Dictionary = {}

func _ready() -> void:
	if debug_log:
		print("[EnemyShooter] 開始 node=%s patterns=%d" % [get_path(), patterns.size()])
		for pattern in patterns:
			print("    start_delay=%.2f shot_count=%d interval=%.2f loop=%s pause=%.2f bullet_count=%d" % [
				pattern.start_delay, pattern.shot_count, pattern.interval,
				pattern.loop, pattern.pause, pattern.bullet_count])
	if _has_conductor():
		return # 譜面で撃つので、Patterns では撃たない
	for pattern in patterns:
		_run_pattern(pattern)

## この敵(シーンのルート)に BeatConductor があるか
func _has_conductor() -> bool:
	var root := owner if owner else get_parent()
	if root == null:
		return false
	for node in root.get_children():
		if node is BeatConductor:
			return true
	return false

## Patterns で撃つのを止める(BeatConductor が、譜面で撃つときに呼ぶ)
func stop() -> void:
	_generation += 1

## 譜面(BeatConductor)から、pattern の shot_index 発目を撃つ
func fire_scheduled(pattern : ShotPattern, shot_index : int) -> void:
	var burst := maxi(pattern.shot_count, 1)
	if shot_index % burst == 0 or not _burst_aims.has(pattern):
		_burst_aims[pattern] = _aim_angle()
	if not _can_fire():
		return
	_fire(pattern, shot_index, _burst_aims[pattern] if pattern.aim_once_per_burst else _aim_angle())

func _run_pattern(pattern : ShotPattern) -> void:
	var generation := _generation
	# Timing Unit が BEATS なら、鳴っている曲(MusicClock)のテンポで数える
	var clock := MusicClock.find_in(get_tree())
	var unit := ShotMath.time_unit(pattern, clock.seconds_per_beat() if clock else 0.5)
	await _wait(pattern.start_delay * unit)
	var shot_index := 0
	while generation == _generation:
		var burst_aim := _aim_angle()
		for i in maxi(pattern.shot_count, 1):
			if generation != _generation:
				return
			if _can_fire():
				_fire(pattern, shot_index, burst_aim if pattern.aim_once_per_burst else _aim_angle())
				if debug_log:
					print("[EnemyShooter] t=%.2f node=%s shot=%d interval=%.2f pause=%.2f pattern=%s" % [
						Time.get_ticks_msec() / 1000.0, get_path(), shot_index, pattern.interval, pattern.pause,
						pattern.resource_path if pattern.resource_path != "" else "(シーン内に埋め込み)"])
			shot_index += 1
			await _wait(pattern.interval * unit)
			if generation != _generation:
				return
		if not pattern.loop:
			return
		await _wait(pattern.pause * unit)

func _can_fire() -> bool:
	if not enabled or is_holding_fire():
		return false
	return not only_when_on_screen or CameraView.visible_rect(self).has_point(global_position)

func _fire(pattern : ShotPattern, shot_index : int, aim_angle : float) -> void:
	var scene := pattern.bullet_scene if pattern.bullet_scene else default_bullet_scene
	if scene == null:
		push_warning("EnemyShooter: 弾シーンが未設定です")
		return
	var parent : Node = bullet_parent if bullet_parent else get_tree().current_scene
	# 弾の並べ方(角度・列弾・ばらつき)は、プレビューと同じ ShotMath で計算する
	var mirror := _is_mirrored()
	for shot in ShotMath.bullets(pattern, shot_index, aim_angle, mirror):
		var bullet : Node2D = scene.instantiate()
		parent.add_child(bullet)
		bullet.z_index = 5
		bullet.global_position = global_position + shot["offset"]
		if bullet.has_method("setup"):
			bullet.setup(Vector2.from_angle(shot["angle"]), pattern.bullet_speed * shot["speed_scale"], pattern.damage, pattern.bullet_accel * shot["speed_scale"])
		if bullet.has_method("set_motion"):
			bullet.set_motion(pattern.motion, shot["speed_scale"], mirror)

## 左右反転して出た敵(Enemy の mirror_x)の砲口なら、弾幕も左右反転する
func _is_mirrored() -> bool:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node.mirror_x
		node = node.get_parent()
	return false

## 自機への角度(自機がいなければ真下)
func _aim_angle() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return (player.global_position - global_position).angle()
	return Vector2.DOWN.angle()

## このノードに紐づく Tween で待つ。ノードが消えたときに安全に処理が止まる
func _wait(seconds : float) -> void:
	if seconds <= 0.0:
		return
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished
