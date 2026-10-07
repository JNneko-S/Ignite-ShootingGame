extends Node2D
class_name EnemyShooter
## 敵に付ける弾発射コンポーネント。ShotPattern を複数登録でき、それぞれ独立して撃つ。
## このノードの位置が発射位置(砲口)になるので、敵の子として好きな位置に置く。
## 自機への狙い撃ちには、Player が "player" グループに入っている必要がある。

@export var patterns : Array[ShotPattern] = []
## ShotPattern 側で弾シーンが未指定のときに使う弾
@export var default_bullet_scene : PackedScene
## 弾の生成先。未設定なら現在のシーン直下
@export var bullet_parent : Node
## true なら、画面内にいる間だけ撃つ(画面外からの不意打ち・無駄撃ち防止)
@export var only_when_on_screen : bool = true
## true なら、発射のたびに使われている値をデバッグ出力に表示する(設定が効いているかの確認用)
@export var debug_log : bool = false

func _ready() -> void:
	if debug_log:
		print("[EnemyShooter] 開始 node=%s patterns=%d" % [get_path(), patterns.size()])
		for pattern in patterns:
			print("    start_delay=%.2f shot_count=%d interval=%.2f loop=%s pause=%.2f bullet_count=%d" % [
				pattern.start_delay, pattern.shot_count, pattern.interval,
				pattern.loop, pattern.pause, pattern.bullet_count])
	for pattern in patterns:
		_run_pattern(pattern)

func _run_pattern(pattern : ShotPattern) -> void:
	await _wait(pattern.start_delay)
	var shot_index := 0
	while true:
		for i in maxi(pattern.shot_count, 1):
			if _can_fire():
				_fire(pattern, shot_index)
				if debug_log:
					print("[EnemyShooter] t=%.2f node=%s shot=%d interval=%.2f pause=%.2f pattern=%s" % [
						Time.get_ticks_msec() / 1000.0, get_path(), shot_index, pattern.interval, pattern.pause,
						pattern.resource_path if pattern.resource_path != "" else "(シーン内に埋め込み)"])
			shot_index += 1
			await _wait(pattern.interval)
		if not pattern.loop:
			return
		await _wait(pattern.pause)

func _can_fire() -> bool:
	return not only_when_on_screen or get_viewport_rect().has_point(global_position)

func _fire(pattern : ShotPattern, shot_index : int) -> void:
	var scene := pattern.bullet_scene if pattern.bullet_scene else default_bullet_scene
	if scene == null:
		push_warning("EnemyShooter: 弾シーンが未設定です")
		return

	# 基準角度(0 = 真下)
	var base := Vector2.DOWN.angle()
	if pattern.aim_at_player:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			base = (player.global_position - global_position).angle()
	base += deg_to_rad(pattern.base_angle + pattern.rotate_per_shot * _rotation_steps(pattern, shot_index))

	var count := maxi(pattern.bullet_count, 1)
	var is_ring := pattern.spread_angle >= 360.0
	var parent : Node = bullet_parent if bullet_parent else get_tree().current_scene

	for i in count:
		var offset := 0.0
		if count > 1:
			if is_ring:
				offset = 360.0 * i / count
			else:
				offset = -pattern.spread_angle / 2.0 + pattern.spread_angle * i / (count - 1)
		var angle := base + deg_to_rad(offset)

		var bullet : Node2D = scene.instantiate()
		parent.add_child(bullet)
		bullet.global_position = global_position
		if bullet.has_method("setup"):
			bullet.setup(Vector2.from_angle(angle), pattern.bullet_speed, pattern.damage, pattern.bullet_accel)

## 回転量(発射回数換算)。reverse_every_shots が設定されていれば、行って戻る動きになる
func _rotation_steps(pattern : ShotPattern, shot_index : int) -> int:
	var n := pattern.reverse_every_shots
	if n <= 0:
		return shot_index
	var k := shot_index % (n * 2)
	return k if k < n else n * 2 - k

## このノードに紐づく Tween で待つ。ノードが消えたときに安全に処理が止まる
func _wait(seconds : float) -> void:
	if seconds <= 0.0:
		return
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished
