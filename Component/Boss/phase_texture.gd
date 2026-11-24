extends Node
class_name PhaseTexture
## ボスの段階が進んだら、親の Sprite2D の絵を差し替える(最終段階で、壊れかけの絵にするなど)。
## ボス(Enemy)の BossPhaseController の phase_started を受け取る。

## この段階(0 が最初)になったら差し替える
@export var at_phase : int = 2
## 差し替える絵と、そのときの Hframes(横に並んだコマの数)
@export var texture : Texture2D
@export var hframes : int = 1

func _ready() -> void:
	var controller := get_parent().owner.get_node_or_null("BossPhaseController") if get_parent().owner else null
	if controller == null:
		controller = _find_controller(get_parent())
	if controller and controller.has_signal("phase_started"):
		controller.phase_started.connect(_on_phase_started)

func _find_controller(node : Node) -> Node:
	while node:
		var found := node.get_node_or_null("BossPhaseController")
		if found:
			return found
		node = node.get_parent()
	return null

func _on_phase_started(index : int) -> void:
	var sprite := get_parent() as Sprite2D
	if sprite == null or texture == null or index < at_phase:
		return
	sprite.texture = texture
	sprite.hframes = maxi(hframes, 1)
	sprite.frame = 0
	# 差し替えた瞬間、白く光る
	sprite.modulate = Color(3.0, 3.0, 3.0)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.4)
