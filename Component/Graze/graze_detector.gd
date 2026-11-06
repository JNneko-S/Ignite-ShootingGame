extends Area2D
class_name GrazeDetector
## グレイズの判定の部品。Area2D(子に CollisionShape2D の円)にアタッチする。
## 敵弾(Hitbox で、DamageSourceType が Enemy)が円に入ったら grazed を出す。
## 同じ弾は1回しかグレイズできない(弾に印を付けるので、出入りを繰り返しても数えない)。
##
## 円の大きさはゲーム中、radius × radius_scale(× 低速中は focus_multiplier)で毎フレーム上書きされる。
## エディタで円を直接変えても効かないので、radius を変える。

## グレイズした瞬間に出る。density: そのとき円の中にある弾の数(密度の目安)
signal grazed(bullet : Area2D, density : int)

## グレイズ済みの弾に付ける印
const GRAZED_META : StringName = &"grazed"

## 通常時のグレイズ判定の半径(px)。大きいほどグレイズしやすい
@export var radius : float = 24.0
## 低速移動中の半径の倍率(1.0 で変化なし)
@export var focus_multiplier : float = 1.0

## 難易度などによる半径の倍率(GameManager → Player が設定する)
var radius_scale : float = 1.0
## 低速移動中か(持ち主が毎フレーム設定する)
var focusing : bool = false
## false のあいだはグレイズしない(無敵中・死亡中など。持ち主が設定する)
var active : bool = true

var _shape : CollisionShape2D

func _ready() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_shape = child
			break
	if _shape and _shape.shape:
		_shape.shape = _shape.shape.duplicate() # シーン内で共有されないよう複製してから半径を変える
	area_entered.connect(_on_area_entered)
	_update_radius()

func _physics_process(_delta : float) -> void:
	_update_radius()

## 今の半径(px)
func current_radius() -> float:
	return radius * radius_scale * (focus_multiplier if focusing else 1.0)

func _update_radius() -> void:
	var circle := _shape.shape as CircleShape2D if _shape else null
	var value := current_radius()
	if circle and not is_equal_approx(circle.radius, value):
		circle.radius = value

func _on_area_entered(area : Area2D) -> void:
	if not active:
		return
	if area is Hitbox and area.damage_source_type == Hitbox.DamageSourceType.Enemy:
		if area.has_meta(GRAZED_META):
			return
		area.set_meta(GRAZED_META, true)
		grazed.emit(area, get_overlapping_areas().size())
