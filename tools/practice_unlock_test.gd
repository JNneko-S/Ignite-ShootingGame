extends Node
## 開発用: ふつうのプレイで、プラクティスが解禁されるかを見る(記録は user://practice_test.cfg)。
##   godot --headless --path . --fixed-fps 60 res://tools/practice_unlock_test.tscn
## 1面のボスの少し前から NORMAL で遊び(自機は無敵。ミスしない)、40 秒後に解禁されたキーを出す
const _Records := preload("res://Component/Practice/practice_records.gd")
var keeper := false
var _t := 0.0

func _ready() -> void:
	if keeper:
		return
	_Records.path_override = "user://practice_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://practice_test.cfg"))
	RunConfig.has_selection = true
	RunConfig.difficulty = 1
	DebugTools.pending_start_time = 115.0
	DebugTools.skip_intro_once = true
	var watcher := Node.new()
	watcher.set_script(get_script())
	watcher.set("keeper", true)
	get_tree().root.add_child.call_deferred(watcher)
	(func() -> void: get_tree().change_scene_to_file("res://stage1.tscn")).call_deferred()

func _physics_process(delta : float) -> void:
	if not keeper:
		return
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_invincibility"):
		p.start_invincibility(1.0)
	if _t > 40.0:
		var cfg := ConfigFile.new()
		cfg.load("user://practice_test.cfg")
		var keys : PackedStringArray = cfg.get_section_keys("unlocked") if cfg.has_section("unlocked") else PackedStringArray()
		print("UNLOCKED %d" % keys.size())
		for k in keys:
			print("  " + k)
		get_tree().quit()
