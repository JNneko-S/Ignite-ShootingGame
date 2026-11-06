extends Node
class_name HitFlash
## 被弾したときに、一瞬光らせる部品。光らせたいノードの子に置いて、flash() を呼ぶ。
## hurtbox を設定すると、そこに弾が当たったときに自動で光る。

## 光らせるノード。未設定なら親
@export var target : CanvasItem
## 自動で光らせるときの Hurtbox(任意)
@export var hurtbox : Hurtbox
## 光る色(1 より大きいほど明るい)と、元に戻るまでの時間(秒)
@export var color : Color = Color(2.5, 2.5, 2.5)
@export var duration : float = 0.08

var _tween : Tween

func _ready() -> void:
	if target == null:
		target = get_parent() as CanvasItem
	if hurtbox:
		hurtbox.recieved_damage.connect(func(_damage) -> void: flash())

func flash() -> void:
	if target == null:
		return
	if _tween:
		_tween.kill()
	target.modulate = color
	_tween = create_tween()
	_tween.tween_property(target, "modulate", Color.WHITE, duration)

## 光っている途中なら止める(ほかの演出で modulate を使うとき)
func stop() -> void:
	if _tween:
		_tween.kill()
