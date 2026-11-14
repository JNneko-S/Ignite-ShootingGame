extends Node
class_name CarSkin
## 車両の見た目を、組の中からランダムに選ぶ部品。車両(Enemy)の子に置く。
## Intact と Wrecks の同じ番号が組になる(壊れていない絵と、残骸の絵)。
## Small Train の絵は、ふつう XX0 が新品・XX1 が壊れた絵だが、緑のコンテナだけ逆(Wgn21 が新品、Wgn20 が壊れた絵)。
## 選んだ絵を親の Sprite2D に入れ、残骸の絵を親の Wreck Texture に入れる。

@export var intact : Array[Texture2D] = []
@export var wrecks : Array[Texture2D] = []
## -1 ならランダム。0 以上なら、その番号の組
@export var variant : int = -1

func _enter_tree() -> void:
	if intact.is_empty():
		return
	var i := variant if variant >= 0 else randi() % intact.size()
	i = clampi(i, 0, intact.size() - 1)
	var parent := get_parent()
	var sprite := parent.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = intact[i]
		sprite.hframes = maxi(roundi(intact[i].get_width() / 26.0), 1)
	if i < wrecks.size() and "wreck_texture" in parent:
		parent.wreck_texture = wrecks[i]
