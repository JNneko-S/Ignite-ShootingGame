extends RefCounted
## プラクティスの記録(解禁・新しく解禁した印・クリア)。user://practice.cfg に保存する。
##   ・解禁: ふつうのプレイで、その難易度でそのボスの攻撃を受けた / 道中の区間を生き残った(通知はしない)
##   ・新しい印(new!): 解禁してから、一覧でまだ選んでいない
##   ・クリア: CLEAR(ふつう)・PLUS(イグナイトなしのプラクティス+)・ASSIST(残機を変えた)
## デバッグ機能を使ったプレイと、プラクティス中は、解禁しない

const PATH := "user://practice.cfg"
const _PracticeRun := preload("res://Component/Practice/practice_run.gd")

## クリアの種類(強い順に、上書きする)
const CLEAR_NONE := ""
const CLEAR_ASSIST := "assist"
const CLEAR_NORMAL := "clear"
const CLEAR_PLUS := "plus"
const _RANK := {"": 0, "assist": 1, "clear": 2, "plus": 3}

static var _config : ConfigFile
## 空でなければ、PATH の代わりにこのファイルを使う(開発用のテストで、遊んでいる人の記録を汚さないため)
static var path_override : String = ""

static func _path() -> String:
	return path_override if path_override != "" else PATH

static func _cfg() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(_path())
	return _config

static func _save() -> void:
	_cfg().save(_path())

## key を解禁する(もう解禁していれば何もしない)
static func unlock(key : String) -> void:
	if DebugTools.used or _PracticeRun.active:
		return
	if _cfg().get_value("unlocked", key, false):
		return
	_cfg().set_value("unlocked", key, true)
	_save()

static func is_unlocked(key : String) -> bool:
	return bool(_cfg().get_value("unlocked", key, false))

## 解禁して、まだ一覧で選んでいない(new!)
static func is_new(key : String) -> bool:
	return is_unlocked(key) and not bool(_cfg().get_value("seen", key, false))

static func mark_seen(key : String) -> void:
	if is_unlocked(key) and not _cfg().get_value("seen", key, false):
		_cfg().set_value("seen", key, true)
		_save()

static func clear_of(key : String) -> String:
	return str(_cfg().get_value("clear", key, CLEAR_NONE))

## クリアを記録する(今の記録より強いときだけ上書き)
static func set_clear(key : String, kind : String) -> void:
	if _RANK.get(kind, 0) <= _RANK.get(clear_of(key), 0):
		return
	_cfg().set_value("clear", key, kind)
	_save()

## デバッグ: 全部解禁する
static func unlock_all(keys : Array) -> void:
	for key in keys:
		_cfg().set_value("unlocked", key, true)
	_save()
