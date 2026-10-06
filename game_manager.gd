extends Node2D
class_name GameManager
## ScrollTest(ステージのルート)にアタッチする配線役。
## Player のグレイズ・被弾 → IgniteGauge、IgniteGauge → UI をつなぐ。

## 未設定なら "player" グループから探す
@export var player : Player
## 未設定なら子の "UI" を使う
@export var ui : IgniteUI

@export_group("イグナイト")
@export var graze_per_level : float = 10.0
@export var density_bonus : float = 0.05

var ignite : IgniteGauge = IgniteGauge.new()

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
	else:
		push_warning("GameManager: Player が見つかりません")

func _on_player_graze_hit(_bullet_position : Vector2, density : int) -> void:
	ignite.add_graze(density)
