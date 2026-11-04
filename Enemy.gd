extends CharacterBody2D
class_name Enemy
## MovePattern に沿って動く敵。HPComponent と Hurtbox で被ダメージ・死亡を処理する。
##
## 必要な子ノード: HPComponent / Hurtbox (Hurtbox直下に CollisionShape2D と CoolDown という名前のTimer)

signal died(enemy : Enemy)

@export var pattern : MovePattern
## true にすると、パターンを左右反転して動く(同じパターンを逆側から出せる)
@export var mirror_x : bool = false
## 移動パターン全体(出現位置と、絶対座標の目標)を、この分だけずらす。
## スポナーが、同じパターンで隊列を組むときに使う
@export var path_offset : Vector2 = Vector2.ZERO
## true なら、mirror_x のとき、見た目と子ノードの位置も左右反転する(砲口が左右逆になる)
@export var mirror_visuals : bool = true

@export_group("ドロップ")
## 倒したときに出すアイテム(パワーアップアイテムなど)。空なら出さない
@export var drop_item_scene : PackedScene
## アイテムを出す確率(0〜1)
@export_range(0.0, 1.0, 0.05) var drop_chance : float = 1.0

@export_group("撃破")
## 倒されたときに、その場に出す爆発。空なら爆発しない
@export var explosion_scene : PackedScene = Explosion.ZAKO
@export var explosion_scale : float = 1.0
## true なら、倒されたときに連鎖爆発 → 大爆発してから消える。
## ボスは StageRunner が is_boss の敵をオンにする。中型機はシーンでオンにして、回数・時間を短めにする
@export var big_death : bool = false
## 連鎖爆発を出す範囲(この敵の位置からのずれ)。大きさが 0 なら、Sprite2D の見た目の範囲を使う
@export var big_death_area : Rect2 = Rect2()
## 連鎖爆発の回数と、かける時間(秒)
@export var big_death_count : int = 15
@export var big_death_duration : float = 2.2
## true なら、連鎖爆発の始めに画面の敵弾を燃やして消す(ボス用)。中型機はオフにして、弾は残す
@export var big_death_burn_bullets : bool = true
## 連鎖爆発のあいだに、この距離(px)だけ流されていく(力尽きて落ちていく感じ)。0 ならその場で爆発
@export var big_death_drift : Vector2 = Vector2.ZERO
## 揺れの強さの倍率(中型機は小さめにする)
@export var big_death_shake_scale : float = 1.0
## 倒されたときの効果音と音量(dB)。空なら鳴らさない
@export var death_sound : AudioStream = preload("res://Assets/Sounds/Explosive/AS_1474525_爆発01-1（短）.mp3")
@export var death_sound_db : float = -15.0
## 連鎖爆発の最後の、大爆発の効果音(big_death のとき)
@export var big_death_sound : AudioStream = preload("res://Assets/Sounds/Explosive/AS_1373492_爆発／攻撃／破壊／爆破／ドカーン.mp3")

@export_group("被弾")
## 弾が当たったときに光る色(1 より大きいほど明るい)と、元に戻るまでの時間(秒)
@export var hit_flash_color : Color = Color(2.5, 2.5, 2.5)
@export var hit_flash_time : float = 0.08

@onready var hp_component : HPComponent = $HPComponent
@onready var hurtbox : Hurtbox = $Hurtbox

var _tween : Tween
var _flash_tween : Tween
var _is_dead : bool = false
## 今の進む向き(CHASE の区間で使う)
var _heading : Vector2 = Vector2.DOWN
var _chase_step : MoveStep
var _chase_elapsed : float = 0.0

signal _chase_finished

func _ready() -> void:
	add_to_group("enemy") # 反射弾の追尾先
	hp_component.is_dead.connect(_die)
	hurtbox.recieved_damage.connect(_on_hurtbox_damage)
	# Hurtbox の area_entered がエディタで未接続なら、ここで接続する
	if not hurtbox.area_entered.is_connected(hurtbox._on_area_entered):
		hurtbox.area_entered.connect(hurtbox._on_area_entered)
	if mirror_x and mirror_visuals:
		_mirror_children()
	if pattern:
		_run_pattern()

## 子ノードの位置を左右反転して、Sprite2D は反転表示にする
func _mirror_children() -> void:
	for child in get_children():
		if child is Node2D:
			child.position.x = -child.position.x
		if child is Sprite2D:
			child.flip_h = not child.flip_h

func _run_pattern() -> void:
	if pattern.override_start_position:
		global_position = _convert_absolute(pattern.start_position)
	for step in pattern.steps:
		await _run_step(step)
		if _is_dead:
			return
	# 全ステップが終わったら(画面外に出ている想定)消す
	queue_free()

func _run_step(step : MoveStep) -> void:
	if step.mode == MoveStep.Mode.CHASE:
		await _run_chase(step)
		return
	var start := global_position
	var target : Vector2
	if step.relative:
		target = global_position + _convert_relative(step.target)
	else:
		target = _convert_absolute(step.target)

	# XとYを同時に、別々のイージングで動かす → カーブになる
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "global_position:x", target.x, step.duration)\
		.set_trans(step.x_trans).set_ease(step.x_ease)
	_tween.tween_property(self, "global_position:y", target.y, step.duration)\
		.set_trans(step.y_trans).set_ease(step.y_ease)
	await _tween.finished
	if target != start:
		_heading = (target - start).normalized()
	await _wait_after(step)

## CHASE: 毎フレーム、自機の方へ少しずつ曲がりながら進む(StagePreview と同じ計算)。
## 動かすのは _physics_process。終わったら _chase_finished が出る(自分のシグナルなので、倒されても安全)
func _run_chase(step : MoveStep) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if step.chase_face_player and player:
		_heading = global_position.direction_to(player.global_position)
	_chase_step = step
	_chase_elapsed = 0.0
	await _chase_finished
	await _wait_after(step)

func _physics_process(delta : float) -> void:
	if _chase_step == null or _is_dead:
		return
	var step := _chase_step
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and step.chase_turn_rate > 0.0:
		var max_turn := deg_to_rad(step.chase_turn_rate) * delta
		var wanted := _heading.angle_to(global_position.direction_to(player.global_position))
		_heading = _heading.rotated(clampf(wanted, -max_turn, max_turn))
	global_position += _heading * step.chase_speed * delta
	_chase_elapsed += delta
	if _chase_elapsed >= step.duration - 0.0001:
		_chase_step = null
		_chase_finished.emit()

func _wait_after(step : MoveStep) -> void:
	if step.wait_after > 0.0 and not _is_dead:
		_tween = create_tween()
		_tween.tween_interval(step.wait_after)
		await _tween.finished

func _convert_absolute(pos : Vector2) -> Vector2:
	if mirror_x:
		var area := CameraView.visible_rect(self) # Camera2D に映っている範囲の、左右の中心で反転する
		pos.x = area.position.x * 2.0 + area.size.x - pos.x
	return pos + path_offset

func _convert_relative(offset : Vector2) -> Vector2:
	if mirror_x:
		offset.x = -offset.x
	return offset

func _on_hurtbox_damage(damage : float, _knockback_dir : Vector2 = Vector2.ZERO) -> void:
	hp_component.apply_damage(ceili(damage))
	if not _is_dead:
		_flash()

## 弾が当たったときに、一瞬光る(本体の modulate を明るくしてから戻す)
func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate = hit_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, hit_flash_time)

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	if _tween:
		_tween.kill()
	_chase_step = null
	died.emit(self)
	_drop_item()
	if big_death:
		_play_big_death()
		return
	Explosion.spawn(get_tree(), explosion_scene, global_position, explosion_scale)
	SoundManager.play_sfx(death_sound, death_sound_db)
	queue_free()

func _drop_item() -> void:
	if drop_item_scene == null or randf() > drop_chance:
		return
	var item := drop_item_scene.instantiate()
	var at := global_position # 自分は先に消えるので、位置を覚えておく
	if item is Node2D:
		item.position = at # シーンの直下に足すので、位置 = 画面(ワールド)の座標
	get_tree().current_scene.add_child.call_deferred(item) # 物理の処理中に倒されることがあるので、後で足す

## ボスの撃破: 撃つのをやめ、全ての爆発エフェクトを順番に体中で起こしてから、大爆発して消える
func _play_big_death() -> void:
	for node in find_children("*", "", true, false):
		if node is EnemyShooter:
			node.enabled = false
			node.stop()
	# 部位(EnemyPart)の当たり判定も含めて、もう当たらないようにする
	for node in find_children("*", "Area2D", true, false):
		if node is Hurtbox:
			node.set_deferred("monitoring", false)
			node.set_deferred("monitorable", false)
	if big_death_burn_bullets:
		get_tree().call_group("enemy_bullet", "burn") # 画面の敵弾は燃えて消える
	if big_death_drift != Vector2.ZERO:
		# 力尽きて、連鎖爆発のあいだ流されていく
		var drift := create_tween()
		drift.tween_property(self, "position", position + big_death_drift, big_death_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var tree := get_tree()
	var area := _death_area()
	# 大爆発の大きさは、見た目の大きさに合わせる(中ボスは小さめ、ボスは大きめ)
	var big_scale := clampf(area.size.length() / 90.0, 2.0, 6.0)
	var interval := big_death_duration / maxi(big_death_count, 1)
	for i in big_death_count:
		var offset := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		var scene : PackedScene = Explosion.ALL[i % Explosion.ALL.size()]
		var effect_scale := randf_range(1.2, 2.0) * (0.6 if scene == Explosion.WAVE else 1.0) # 衝撃波は白く大きいので控えめ
		Explosion.spawn(tree, scene, global_position + offset, effect_scale)
		SoundManager.play_sfx(death_sound, death_sound_db - 4.0, randf_range(0.9, 1.1)) # 連鎖の音は少し小さく、高さをばらす
		_shake(4.0 * big_death_shake_scale)
		await tree.create_timer(interval).timeout

	# 大爆発: 中心に大きな爆発と衝撃波、周りに小さな爆発
	var center := global_position + area.get_center()
	Explosion.spawn(tree, Explosion.EXPLOSIVE, center, big_scale)
	SoundManager.play_sfx(big_death_sound, death_sound_db)
	Explosion.spawn(tree, Explosion.WAVE, center, big_scale * 0.8)
	for i in 8:
		Explosion.spawn(tree, Explosion.ZAKO, center + Vector2.from_angle(TAU * i / 8.0) * area.size.length() * 0.25, big_scale * 0.5)
	_shake(12.0 * big_death_shake_scale)
	var fade := create_tween()
	fade.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.08)
	fade.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	await fade.finished
	queue_free()

## 連鎖爆発の範囲。big_death_area が空なら、子の Sprite2D の見た目を全部囲む範囲
func _death_area() -> Rect2:
	if big_death_area.has_area():
		return big_death_area
	var area := Rect2()
	var first := true
	for child in get_children():
		if child is Sprite2D:
			var rect : Rect2 = child.get_rect()
			rect = Rect2(child.position + rect.position * child.scale, rect.size * child.scale)
			area = rect if first else area.merge(rect)
			first = false
	return area if not first else Rect2(-24, -24, 48, 48)

func _shake(strength : float) -> void:
	for child in get_children():
		if child is Sprite2D:
			var base : Vector2 = child.get_meta("shake_base", child.position)
			child.set_meta("shake_base", base)
			var shake := create_tween()
			shake.tween_property(child, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.04)
			shake.tween_property(child, "position", base, 0.06)
