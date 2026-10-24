@tool
extends Resource
class_name BulletStep
## 敵弾の動き1区間。ShotPattern の Motion に並べると、弾が順番にこの動きをする。
## 例) 減速して止まる → 自機の方を向いて加速する → 曲がりながら飛ぶ
##
## 最後の区間が終わったら、その時点の速度と向きのまま、まっすぐ飛ぶ。

enum TurnMode {
	KEEP,       ## 向きを変えない
	ADD,        ## 今の向きから Turn Angle 度だけ回す
	AIM_PLAYER, ## 自機の方を向く(Turn Angle 度のずれを足す)
	ABSOLUTE,   ## Turn Angle 度の向きにする(0 = 真下、正の値は反時計回り)
}

## この区間の長さ(秒)
@export var duration : float = 1.0

@export_group("向き(区間の始めに1回)")
@export var turn_mode : TurnMode = TurnMode.KEEP
@export var turn_angle : float = 0.0

@export_group("速度")
## オフなら、前の区間の終わりの速度のまま
@export var change_speed : bool = true
## 区間の終わりの速度(px/秒)。区間の始めの速度から、イージングで変わる
@export var target_speed : float = 0.0
@export var speed_trans : Tween.TransitionType = Tween.TRANS_SINE
@export var speed_ease : Tween.EaseType = Tween.EASE_OUT

@export_group("曲がり")
## この区間の間、向きが毎秒この角度だけ回る(度/秒)。正の値は反時計回り
@export var angular_velocity : float = 0.0
