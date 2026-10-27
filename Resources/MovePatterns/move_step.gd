extends Resource
class_name MoveStep
## 敵の移動1区間。X軸とY軸で別々のイージングを指定できるので、
## 組み合わせることでカーブした軌道になります。
##   例) Xを EASE_IN、Yを EASE_OUT にすると、縦に進んでから横へ膨らむ曲線
##
## Mode を CHASE にすると、目標座標ではなく、向きと速さで動く(自機を追いかける突撃など)。

enum Mode {
	TWEEN, ## 目標座標へ、イージングで動く
	CHASE, ## 今の向きに Chase Speed で進みながら、自機の方へ Chase Turn Rate で曲がる(0 ならまっすぐ)
}

@export var mode : Mode = Mode.TWEEN

## 目標座標。relative が true なら「この区間の開始位置からの移動量」
@export var target : Vector2 = Vector2.ZERO
@export var relative : bool = false
## かける時間(秒)
@export var duration : float = 1.0
## この区間が終わった後の待機時間(秒)
@export var wait_after : float = 0.0

@export_group("追いかける(Mode が CHASE のとき)")
## 進む速さ(px/秒)
@export var chase_speed : float = 150.0
## 自機の方へ曲がる速さ(度/秒)。0 ならまっすぐ進む
@export var chase_turn_rate : float = 120.0
## true なら、区間の始めに自機の方を向く。false なら前の動きの向きのまま
@export var chase_face_player : bool = true

@export_group("X軸のイージング")
@export var x_trans : Tween.TransitionType = Tween.TRANS_LINEAR
@export var x_ease : Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Y軸のイージング")
@export var y_trans : Tween.TransitionType = Tween.TRANS_LINEAR
@export var y_ease : Tween.EaseType = Tween.EASE_IN_OUT
