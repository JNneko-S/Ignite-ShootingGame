extends CanvasLayer
class_name ShutterTransition
## 画面を覆うシャッター(上下2枚)。閉まった状態で使い、シーンを切り替えてから開く。
## 子に ShutterTop / ShutterBottom(shutter.gdshader の ColorRect)と、FxLayer/ScreenFx(画面のノイズ)を置く。
##
## change_scene_and_open(path): このシャッターをシーンの外(ルート)へ移してから、シーンを切り替え、
##   新しいシーンの上でシャッターを開いて、自分は消える。ノイズも開くあいだに消えていく。

## 開くまでの時間(秒)
@export var open_time : float = 0.65
## 開く音(シーンに置いた AudioStreamPlayer)
@export var open_sound : AudioStreamPlayer

@onready var _top : ColorRect = $ShutterTop
@onready var _bottom : ColorRect = $ShutterBottom
@onready var _fx : ColorRect = get_node_or_null("FxLayer/ScreenFx")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layout_closed()

## 画面の大きさに合わせて、閉まった位置に置く
func layout_closed() -> void:
	var view := get_viewport().get_visible_rect().size
	var half := ceilf(view.y * 0.5)
	_top.size = Vector2(view.x, half)
	_top.position = Vector2.ZERO
	_bottom.size = Vector2(view.x, half)
	_bottom.position = Vector2(0.0, half)
	for shutter in [_top, _bottom]:
		(shutter.material as ShaderMaterial).set_shader_parameter("rect_size", shutter.size)
	if _fx:
		_fx.position = Vector2.ZERO
		_fx.size = view

## 開いた位置(画面の外)に置く。close() の前に呼ぶ
func layout_open() -> void:
	layout_closed()
	_top.position.y = -_top.size.y
	_bottom.position.y = _bottom.size.y * 2.0
	if _fx:
		(_fx.material as ShaderMaterial).set_shader_parameter("strength", 0.0)

## 上下から閉まる(最後にガシャンと跳ねる)。閉まりきるまで待てる
func close(time : float = 0.5) -> void:
	var half := _top.size.y
	var fx_strength := 0.4
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_top, "position:y", 0.0, time)
	tween.tween_property(_bottom, "position:y", half, time)
	if _fx:
		var material := _fx.material as ShaderMaterial
		tween.tween_method(func(v : float) -> void: material.set_shader_parameter("strength", v), 0.0, fx_strength, time)
	await get_tree().create_timer(time * 0.36, true).timeout # 跳ねる動きで、最初に閉まりきる時刻
	SoundManager.play(open_sound, 0.75)
	await tween.finished

## シーンを切り替えて、その上でシャッターを開く
func change_scene_and_open(path : String) -> void:
	reparent(get_tree().root)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	SoundManager.play(open_sound)
	var half := _top.size.y
	var open := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	open.tween_property(_top, "position:y", -half - 4.0, open_time)
	open.tween_property(_bottom, "position:y", half * 2.0 + 4.0, open_time)
	if _fx:
		var material := _fx.material as ShaderMaterial
		var from := float(material.get_shader_parameter("strength"))
		open.tween_method(func(v : float) -> void: material.set_shader_parameter("strength", v), from, 0.0, open_time)
	await open.finished
	queue_free()
