extends Node
## シーンの切り替えを、つなぎ目なく見せる(自動読み込み: SceneSwitcher)。
##   SceneSwitcher.change("res://stage2.tscn")
## 切り替える直前の画面を写真に撮って、いちばん手前に貼ったまま、次のシーンを裏で読み込む。
## 次のシーンが描かれ始めたら、写真をすっと消す。読み込みのあいだの灰色の画面や、引っかかりが見えない。

## 写真を消すまでの時間(秒)
const FADE_TIME : float = 0.25

var _busy : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## path のシーンへ、つなぎ目なく切り替える
func change(path : String, fade_time : float = FADE_TIME) -> void:
	if path == "" or _busy:
		return
	_busy = true
	var tree := get_tree()
	# 1. 今の画面を写真にして、いちばん手前に貼る
	var cover := _make_cover()
	# 2. 次のシーンを読み込む(読み込みのあいだも、写真が見えている)。
	# 別のスレッドでは読み込まない: 今のステージが動いている(弾や弾幕のリソースを使っている)あいだに、
	# 同じリソースを別のスレッドで読み込むと、壊れたリソースが次のステージに残って、あとで落ちることがある
	# (3面から4面へ移ったあとだけ落ちる事例)。止まって見えるのは、写真に隠れる一瞬だけ
	await tree.process_frame # 写真が貼られてから読み込む
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneSwitcher: シーンを読み込めません: " + path)
		_busy = false
		return
	# 3. 切り替えて、描かれ始めるのを待ってから、写真を消す
	tree.change_scene_to_packed(packed)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(cover):
		var rect := cover.get_child(0) as CanvasItem
		var tween := create_tween()
		tween.tween_property(rect, "modulate:a", 0.0, fade_time)
		tween.tween_callback(cover.queue_free)
	_busy = false

## 今の画面の写真を、いちばん手前の層に貼る
func _make_cover() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 128
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var image := get_viewport().get_texture().get_image()
	if image:
		rect.texture = ImageTexture.create_from_image(image)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	return layer
