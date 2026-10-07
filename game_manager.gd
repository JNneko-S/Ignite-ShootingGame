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
## イグナイト終了後、再発動できるようになるまでの時間(秒)。この間もゲージは貯まる
@export var ignite_cooldown : float = 5.0

var ignite : IgniteGauge = IgniteGauge.new()
var _cooldown_until_msec : int = 0

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if ui == null:
		ui = get_node_or_null("UI") as IgniteUI

	ignite.graze_per_level = graze_per_level
	ignite.density_bonus = density_bonus

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
		return
	var used_level := ignite.consume()
	player.start_ignite(used_level, ignite.invincible_time(used_level))

func _on_player_ignite_ended() -> void:
	_cooldown_until_msec = Time.get_ticks_msec() + int(ignite_cooldown * 1000.0)

func is_ignite_cooling_down() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_msec

## 再発動までの残り秒数(UI表示用)
func ignite_cooldown_remaining() -> float:
	return maxf(0.0, (_cooldown_until_msec - Time.get_ticks_msec()) / 1000.0)
