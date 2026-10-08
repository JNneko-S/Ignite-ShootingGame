extends Node2D
class_name GameManager
## ScrollTest(ステージのルート)にアタッチする配線役。
## Player のグレイズ・被弾 → IgniteGauge、IgniteGauge → UI をつなぐ。

## 未設定なら "player" グループから探す
@export var player : Player
## 未設定なら子の "UI" を使う
@export var ui : IgniteUI

## 残機を表示するラベル(任意)
@export var lives_label : LivesLabel

@export_group("イグナイト")
@export var graze_per_level : float = 10.0
@export var density_bonus : float = 0.05
## イグナイト終了後に、敵弾を消し続ける時間(秒)。この間は再発動できない
@export var ignite_bullet_cancel_time : float = 2.0
## 弾消しが終わってから、再発動できるようになるまでの時間(秒)。この間もゲージは貯まる
@export var ignite_cooldown : float = 5.0
## 発動時間(無敵時間)= レベル × この値(秒)。Lv1:0.5秒 / Lv6:3.0秒 / Lv10:5.0秒
@export var ignite_seconds_per_level : float = 0.5
## レベルごとに発動時間を直接指定する(Lv1から順に、秒)。空なら上の式を使う。
## 例: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
@export var ignite_custom_durations : Array[float] = []
## true なら、イグナイトを押したときの結果(発動 / できない理由)を出力する
@export var debug_ignite : bool = false

var ignite : IgniteGauge = IgniteGauge.new()
var _cancel_until_msec : int = 0
var _cooldown_until_msec : int = 0

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if ui == null:
		ui = get_node_or_null("UI") as IgniteUI

	ignite.graze_per_level = graze_per_level
	ignite.density_bonus = density_bonus
	ignite.invincible_seconds_per_level = ignite_seconds_per_level
	ignite.custom_durations = ignite_custom_durations

	if ui:
		ui.bind(ignite)
	else:
		push_warning("GameManager: IgniteUI が見つかりません")

	if player:
		player.graze_hit.connect(_on_player_graze_hit)
		player.damaged.connect(ignite.on_miss)
		player.ignite_pressed.connect(_on_player_ignite_pressed)
		player.ignite_ended.connect(_on_player_ignite_ended)
		if lives_label:
			lives_label.bind(player)
	else:
		push_warning("GameManager: Player が見つかりません")

func _on_player_graze_hit(_bullet_position : Vector2, density : int) -> void:
	# イグナイト中はグレイズしてもゲージは貯まらない
	if player and player.is_igniting:
		return
	ignite.add_graze(density)

## イグナイト発動: ゲージを消費して、レベルに応じた無敵時間でプレイヤーを発動させる
func _on_player_ignite_pressed() -> void:
	if player.is_igniting or not ignite.can_ignite() or is_ignite_cooling_down():
		if debug_ignite:
			print("[Ignite] 発動できません: 発動中=%s / レベル=%d(Lv1以上が必要) / クールダウン残り=%.1f秒" % [
				player.is_igniting, ignite.level, ignite_cooldown_remaining()])
		return
	var used_level := ignite.consume()
	if debug_ignite:
		print("[Ignite] 発動 Lv%d 無敵%.1f秒" % [used_level, ignite.invincible_time(used_level)])
	player.start_ignite(used_level, ignite.invincible_time(used_level))

## イグナイト終了 → 弾消し(ignite_bullet_cancel_time) → クールタイム(ignite_cooldown) の順に進む
func _on_player_ignite_ended() -> void:
	var now := Time.get_ticks_msec()
	_cancel_until_msec = now + int(ignite_bullet_cancel_time * 1000.0)
	_cooldown_until_msec = _cancel_until_msec + int(ignite_cooldown * 1000.0)

## 弾消しの間は、敵弾を毎フレーム消す(反射弾は "enemy_bullet" グループから外れているので残る)
func _physics_process(_delta : float) -> void:
	if is_bullet_canceling():
		get_tree().call_group("enemy_bullet", "queue_free")

func is_bullet_canceling() -> bool:
	return Time.get_ticks_msec() < _cancel_until_msec

## 弾消し中、またはクールタイム中か(この間は発動できない)
func is_ignite_cooling_down() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_msec

## 再発動できるまでの残り秒数(弾消しの時間を含む。UI表示用)
func ignite_cooldown_remaining() -> float:
	return maxf(0.0, (_cooldown_until_msec - Time.get_ticks_msec()) / 1000.0)
