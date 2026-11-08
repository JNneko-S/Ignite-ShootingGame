@tool
extends Node2D
class_name GroundBlocker
## 地上の敵が通れない場所の目印(四角)。背景の地面の絵(Sprite2D)の子に置き、物(ホーム、車止め、穴など)に重ねる。
## エディタでは赤い四角で見え、ゲーム中は見えない。背景の子なので、背景と一緒に流れて、揺れる。
## 回転・拡大してもよい(親の背景が 2.6 倍なら、Size は背景のテクスチャの px で入れる)。
##
## 地面の絵にそのまま描いてある物は、透明かどうかで見分けられないので、これで教える。
## 屋根の層の建物や、"ground_obstacle" グループの Sprite2D は、置かなくても自動でよける(GroundObstacles)。

## 四角の大きさ(このノードの中の px)。中心がこのノードの位置
@export var size : Vector2 = Vector2(32, 32) :
	set(value):
		size = value
		queue_redraw()

func _enter_tree() -> void:
	add_to_group(GroundObstacles.GROUP)

func _ready() -> void:
	queue_redraw()

## world_point(画面の座標)がこの四角の中か
func blocks(world_point : Vector2) -> bool:
	return Rect2(-size * 0.5, size).has_point(to_local(world_point))

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(1.0, 0.2, 0.2, 0.25), true)
	draw_rect(rect, Color(1.0, 0.3, 0.3, 0.9), false, 1.0)
