extends Node
var until := 60.0
var _t := 0.0
var _next := 0.0
func _physics_process(delta : float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility"):
		p.start_invincibility(1.0)
	if _t >= _next:
		_next += 10.0
		var scene := get_tree().current_scene
		print("t=%.0f scene=%s bullets=%d enemies=%d" % [_t, scene.scene_file_path if scene else "-",
			get_tree().get_nodes_in_group("enemy_bullet").size(), get_tree().get_nodes_in_group("enemy").size()])
	if _t > until:
		print("END")
		get_tree().quit()
