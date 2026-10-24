@tool
extends EditorPlugin
## 下部パネルに「ステージ」タブを追加する。
## 編集中のシーンにある StagePreview を見つけて、そのステージのタイムラインを表示する。

const StageTimeline = preload("res://addons/stage_editor/stage_timeline.gd")

var _panel : StageTimeline

func _enter_tree() -> void:
	_panel = StageTimeline.new()
	_panel.undo_redo = get_undo_redo()
	add_control_to_bottom_panel(_panel, "ステージ")
	scene_changed.connect(_on_scene_changed)

func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
	_panel = null

func _handles(object : Object) -> bool:
	return object is StagePreview

func _edit(object : Object) -> void:
	if object is StagePreview:
		_panel.set_preview(object)

func _make_visible(visible : bool) -> void:
	if visible:
		make_bottom_panel_item_visible(_panel)

func _on_scene_changed(_root : Node) -> void:
	_panel.set_preview(null) # 次の描画で、新しいシーンから探し直す
