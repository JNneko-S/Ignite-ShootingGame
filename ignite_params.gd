extends Resource
class_name IgniteParams
## イグナイトで変色した弾(反射弾)の設定をまとめたリソース。
## IgniteAura に割り当てる。

@export_group("当たり判定(必ず設定)")
## 反射弾が持つレイヤー。敵の Hurtbox が拾う「自弾のレイヤー」にする
@export_flags_2d_physics var ignited_collision_layer : int = 0
## 反射弾が連鎖で探す相手のレイヤー。「敵弾のレイヤー」にする
@export_flags_2d_physics var ignited_collision_mask : int = 0

@export_group("ダメージ")
## 反射弾1発あたりのダメージ(距離減衰は受けない。直接触れた弾も連鎖弾も同じ)
@export var base_damage : float = 3.0

@export_group("軌道")
## 反射弾の速度(px/秒)
@export var reflect_speed : float = 420.0
## 敵へ向きを変える速さ(度/秒)。最初は緩やかで、弧を描く
@export var turn_rate_deg : float = 120.0
## 時間とともに旋回が鋭くなる量(度/秒²)。いずれ必ず敵に当たるようにする
@export var turn_rate_growth_deg : float = 400.0
## 揺れの大きさ(度)
@export var sway_amplitude_deg : float = 25.0
## 揺れの速さ(回/秒)
@export var sway_frequency : float = 2.5

@export_group("色")
## オーラに直接触れて変色した弾の色
@export var direct_color : Color = Color(1.0, 0.65, 0.2)
## 連鎖で変色した弾の色
@export var chain_color : Color = Color(1.0, 0.3, 0.2)

@export_group("連鎖")
@export var chain_enabled : bool = true
