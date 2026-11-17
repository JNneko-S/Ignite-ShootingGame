extends RefCounted
class_name TutorialProgress
## 操作を覚えたかどうかの記録(user://progress.cfg)。覚えたら、そのヒントは二度と出さない。
## ハイスコアとは別のファイルにしてある。デバッグ機能を使ったプレイでは、保存しない。

const SAVE_PATH : String = "user://progress.cfg"

static var _loaded : bool = false
static var _ignite_used : bool = false

## イグナイトを一度でも使ったことがあるか
static func ignite_used() -> bool:
	_load()
	return _ignite_used

## イグナイトを使った。次からは、イグナイトのヒントを出さない
static func mark_ignite_used() -> void:
	_load()
	if _ignite_used:
		return
	_ignite_used = true
	if DebugTools.used:
		return
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("tutorial", "ignite_used", true)
	config.save(SAVE_PATH)

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_ignite_used = bool(config.get_value("tutorial", "ignite_used", false))
