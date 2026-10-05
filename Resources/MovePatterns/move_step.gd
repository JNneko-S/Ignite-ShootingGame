extends Resource
class_name MoveStep
## 敵の移動1区間。X軸とY軸で別々のイージングを指定できるので、
## 組み合わせることでカーブした軌道になります。
##   例) Xを EASE_IN、Yを EASE_OUT にすると、縦に進んでから横へ膨らむ曲線

## 目標座標。relative が true なら「この区間の開始位置からの移動量」
@export var target : Vector2 = Vector2.ZERO
@export var relative : bool = false
## かける時間(秒)
@export var duration : float = 1.0
## この区間が終わった後の待機時間(秒)
@export var wait_after : float = 0.0

@export_group("X軸のイージング")
@export var x_trans : Tween.TransitionType = Tween.TRANS_LINEAR
@export var x_ease : Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Y軸のイージング")
@export var y_trans : Tween.TransitionType = Tween.TRANS_LINEAR
@export var y_ease : Tween.EaseType = Tween.EASE_IN_OUT
