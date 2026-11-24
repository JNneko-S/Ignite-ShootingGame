extends SceneTree
## 開発用: ステージを頭なし(--headless)で流し、地上の敵と置いた壁(GroundBlockArea / GroundBlocker)の関係を記録する。
## godot --headless --fixed-fps 60 -s res://tools/probe_ground_walls.gd -- res://stage4.tscn 120 [from]

var _scene_path := "res://stage4.tscn"
var _until := 120.0
var _from := 0.0
var _time := 0.0
var _next_log := 0.0
var _reported := {}
var _spawned := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene_path = args[0]
	if args.size() > 1:
		_until = float(args[1])
	if args.size() > 2:
		_from = float(args[2])
	change_scene_to_packed(load(_scene_path))

## 壁(多角形・四角)の画面での外枠
func _wall_rects() -> Array:
	var result := []
	for node in get_nodes_in_group(GroundObstacles.GROUP):
		if node is GroundBlockArea:
			var poly : PackedVector2Array = (node as GroundBlockArea).polygon
			var r := Rect2(node.to_global(poly[0]), Vector2.ZERO)
			for p in poly:
				r = r.expand(node.to_global(p))
			result.append([node.name, r])
	return result

func _process(delta : float) -> bool:
	_time += delta
	var player := get_first_node_in_group("player")
	if player and player.has_method("start_invincibility"):
		player.start_invincibility(1.0)
	var log_now := _time >= _next_log
	if log_now:
		_next_log += 1.0
	for unit in get_nodes_in_group(&"ground_unit"):
		var enemy := unit.get_parent() as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var id := enemy.get_instance_id()
		if enemy.is_queued_for_deletion():
			continue
		if not _spawned.has(id):
			_spawned[id] = _time
		elif _spawned[id] >= 0.0 and _time - _spawned[id] > 0.3:
			_spawned[id] = -1.0
			if _time >= _from:
				print("ALIVE t=%.1f %s pos=%s" % [_time, enemy.scene_file_path.get_file(), enemy.global_position.round()])
		var r := 34.0
		var near := false
		for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
			if GroundObstacles.is_walled(self, enemy.global_position + o):
				near = true
		if near and not _reported.has(id):
			_reported[id] = true
			print("TOUCH t=%.1f %s pos=%s center_walled=%s" % [_time, enemy.scene_file_path.get_file(), enemy.global_position.round(), GroundObstacles.is_walled(self, enemy.global_position)])
	if log_now and _time >= _from:
		var view := Rect2()
		var cam := get_root().get_viewport().get_camera_2d()
		if cam:
			view = CameraView.visible_rect(cam)
		print("t=%.0f view=%s walls=%s" % [_time, view, _wall_rects()])
	return _time >= _until
