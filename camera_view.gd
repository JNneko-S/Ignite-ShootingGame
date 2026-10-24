@tool
extends RefCounted
class_name CameraView
## Camera2D に映っている範囲(ワールド座標)を返す。
## 「画面の範囲」が必要なところ(自機の移動範囲、敵の左右反転、画面内判定、エディタのプレビューの枠)は、
## 全てこれを使って、カメラの位置・ズームが変わってもずれないようにする。

## ゲーム中: node のキャンバスで、今カメラに映っている範囲
static func visible_rect(node : CanvasItem) -> Rect2:
	return node.get_canvas_transform().affine_inverse() * node.get_viewport_rect()

## エディタ: シーンの中の Camera2D に映る範囲。カメラがなければ (0, 0) から画面の大きさまで
static func scene_rect(scene_root : Node) -> Rect2:
	var camera : Camera2D = null
	if scene_root:
		if scene_root is Camera2D:
			camera = scene_root
		else:
			for node in scene_root.find_children("*", "Camera2D", true, false):
				if (node as Camera2D).enabled:
					camera = node
					break
	if camera == null:
		return Rect2(Vector2.ZERO, screen_size())
	return _camera_rect(camera.global_position, camera.zoom, camera.offset, camera.anchor_mode)

## エディタ: シーンのファイル(開いていなくてよい)の Camera2D に映る範囲。
## カメラがシーンのルートの直下にある前提で、ファイルの設定を読む
static func packed_scene_rect(scene : PackedScene) -> Rect2:
	var state := scene.get_state() if scene else null
	if state:
		for i in state.get_node_count():
			if state.get_node_type(i) != &"Camera2D":
				continue
			var values := {"position": Vector2.ZERO, "zoom": Vector2.ONE, "offset": Vector2.ZERO,
					"anchor_mode": Camera2D.ANCHOR_MODE_DRAG_CENTER}
			for p in state.get_node_property_count(i):
				var property := String(state.get_node_property_name(i, p))
				if values.has(property):
					values[property] = state.get_node_property_value(i, p)
			return _camera_rect(values["position"], values["zoom"], values["offset"], values["anchor_mode"])
	return Rect2(Vector2.ZERO, screen_size())

## ゲームの画面の大きさ(ズーム1のとき)。ウィンドウの縦横比が違えば、Stretch Aspect が expand のときと同じく広げる
static func screen_size() -> Vector2:
	var size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	var window := Vector2(
		float(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		float(ProjectSettings.get_setting("display/window/size/window_height_override", 0)))
	if window.x > 0.0 and window.y > 0.0 and ProjectSettings.get_setting("display/window/stretch/aspect", "keep") == "expand":
		if window.x / window.y > size.x / size.y:
			size.x = size.y * window.x / window.y
		else:
			size.y = size.x * window.y / window.x
	return size

static func _camera_rect(position : Vector2, zoom : Vector2, offset : Vector2, anchor_mode : int) -> Rect2:
	var view := screen_size() / zoom
	if anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		return Rect2(position + offset, view)
	return Rect2(position + offset - view / 2.0, view)
