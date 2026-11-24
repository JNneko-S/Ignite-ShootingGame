@tool
extends Polygon2D
class_name GroundBlockArea
## 地上の敵(戦車など)が入れない場所(多角形)。背景の地面の絵(Sprite2D)の子に置き、壁や穴の形に点を打つ。
## Polygon2D なので、エディタの多角形の編集で点を動かせる。エディタでは赤く見え、ゲーム中は見えない。
## 背景の子なので、背景と一緒に流れて、揺れる。斜めの壁など、四角(GroundBlocker)で合わせにくい所に使う。

func _enter_tree() -> void:
	add_to_group(GroundObstacles.GROUP)
	if not Engine.is_editor_hint():
		visible = false # 当たり判定だけ使う(見えなくても blocks は効く)

func _ready() -> void:
	if Engine.is_editor_hint() and color == Color.WHITE:
		color = Color(1.0, 0.15, 0.15, 0.45)

## world_point(画面の座標)が、この多角形の中か
func blocks(world_point : Vector2) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(to_local(world_point), polygon)
