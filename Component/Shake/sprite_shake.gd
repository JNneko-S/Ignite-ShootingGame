extends RefCounted
class_name SpriteShake
## 見た目を一瞬揺らす。SpriteShake.shake(持ち主, 強さ) で呼ぶ(ノードを置く必要はない)。
## 持ち主の子の Sprite2D だけを揺らすので、当たり判定や移動には影響しない。

## body の子の Sprite2D を、strength(px)だけ一瞬揺らして戻す
static func shake(body : Node, strength : float) -> void:
	for child in body.get_children():
		if child is Sprite2D:
			var base : Vector2 = child.get_meta("shake_base", child.position)
			child.set_meta("shake_base", base)
			var tween : Tween = child.create_tween()
			tween.tween_property(child, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.04)
			tween.tween_property(child, "position", base, 0.06)
