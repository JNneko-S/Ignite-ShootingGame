extends RefCounted
class_name GroundObstacles
## 地上の敵が通れない場所(建物・貨車など)を調べる。GroundUnit が使う。
##
## "ground_obstacle" グループのノードが障害物になる:
##   ・GroundBlocker(エディタで置く四角)は、その四角の中が通れない。地面の絵に描いてある物に重ねて使う
##   ・Sprite2D なら、その絵の不透明な所(アルファが alpha_threshold 以上)が通れない
##     → 背景の屋根の層(建物だけが描いてある絵)をグループに入れると、建物を全部よけるようになる
##   ・Sprite2D でないノード(IgniteTarget など)は、子の Sprite2D の不透明な所が通れない
## 自分で置いた物(箱、柵など)も、Sprite2D をこのグループに入れれば障害物になる。

const GROUP : StringName = &"ground_obstacle"

## Texture → Image(ピクセルを読むため)。同じ絵は1回だけ読み込む
static var _images : Dictionary = {}

## world_point(画面の座標)が通れない場所か
static func is_blocked(tree : SceneTree, world_point : Vector2, alpha_threshold : float = 0.6) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		if node is GroundBlocker:
			if (node as GroundBlocker).blocks(world_point):
				return true
		elif node is Sprite2D:
			if _sprite_blocks(node, world_point, alpha_threshold):
				return true
		elif node is Node:
			for child in (node as Node).get_children():
				if child is Sprite2D and _sprite_blocks(child, world_point, alpha_threshold):
					return true
	return false

static func _sprite_blocks(sprite : Sprite2D, world_point : Vector2, alpha_threshold : float) -> bool:
	if sprite.texture == null or not sprite.is_visible_in_tree():
		return false
	var local := sprite.to_local(world_point)
	var rect := sprite.get_rect()
	if not rect.has_point(local):
		return false
	var image := _image_of(sprite.texture)
	if image == null:
		return true # 読めない絵は、四角全体を障害物とみなす
	var pixel := local - rect.position
	if sprite.flip_h:
		pixel.x = rect.size.x - 1.0 - pixel.x
	if sprite.flip_v:
		pixel.y = rect.size.y - 1.0 - pixel.y
	# hframes / vframes の、今のコマの位置を足す
	var frame_size := rect.size
	pixel += Vector2(sprite.frame % maxi(sprite.hframes, 1), sprite.frame / maxi(sprite.hframes, 1)) * frame_size
	if sprite.region_enabled:
		pixel += sprite.region_rect.position
	var x := clampi(int(pixel.x), 0, image.get_width() - 1)
	var y := clampi(int(pixel.y), 0, image.get_height() - 1)
	return image.get_pixel(x, y).a >= alpha_threshold

static func _image_of(texture : Texture2D) -> Image:
	var key := texture.get_rid()
	if _images.has(key):
		return _images[key]
	var image := texture.get_image()
	if image and image.is_compressed():
		image.decompress()
	_images[key] = image
	return image
