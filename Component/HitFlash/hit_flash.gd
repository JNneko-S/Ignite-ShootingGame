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

@export_group("撃ち込み度")
## 撃ち込まれるほど(HP が減るほど)、光ったあとに戻る色が Damage Color に近づく。
## 固い敵が「効いている」のが見て分かる。HP は target の子か兄弟の HPComponent から読む
@export var damage_color : Color = Color(1.0, 0.45, 0.35)
## 色の変わる強さ(0 なら変わらない、1 で HP 0 のときに Damage Color そのもの)
@export_range(0.0, 1.0, 0.05) var damage_tint : float = 0.75

var _tween : Tween
var _hp : HPComponent

func _ready() -> void:
	if target == null:
		target = get_parent() as CanvasItem
	_hp = _find_hp()
	if hurtbox:
		hurtbox.recieved_damage.connect(func(_damage) -> void: flash())

func flash() -> void:
	if target == null:
		return
	if _tween:
		_tween.kill()
	target.modulate = color
	_tween = create_tween()
	_tween.tween_property(target, "modulate", rest_color(), duration)

## 光っていないときの色(撃ち込まれるほど赤い)
func rest_color() -> Color:
	if _hp == null or _hp.max_hp <= 0 or damage_tint <= 0.0:
		return Color.WHITE
	var lost := 1.0 - clampf(float(_hp.hp) / float(_hp.max_hp), 0.0, 1.0)
	return Color.WHITE.lerp(damage_color, lost * damage_tint)

func _find_hp() -> HPComponent:
	for parent in [target, get_parent()]:
		if parent == null:
			continue
		var hp := (parent as Node).get_node_or_null("HPComponent") as HPComponent
		if hp:
			return hp
	return null

## 光っている途中なら止める(ほかの演出で modulate を使うとき)
func stop() -> void:
	if _tween:
		_tween.kill()
