extends RefCounted
class_name PreloadCache
## ゲームで使う重いリソース(全ステージ・敵・弾幕・ボス・Union・エンディング)を、決まった場所でまとめて読み込んでおく。
## 読み込んだものはここで持ち続けるので、ステージの切り替えやボスの登場のときに、読み込みの引っかかりが起きない。
##
## 読み込むのは、ロード画面(LoadingOverlay)のあいだだけ。ステージが動いていないところで、
## 同じスレッドで少しずつ読み込む(別スレッドで読み込むと、動いているステージと同じリソースを取り合って壊れることがある)。
##
##   PreloadCache.is_warm()      … もう全部読み込んだか
##   PreloadCache.begin()        … 読み込む順番を作る(ROOTS から依存をたどり、依存されるものから先に)
##   PreloadCache.step(usec)     … 決めた時間だけ読み込みを進め、進み具合(0〜1)を返す

## ここから依存をたどって、全部読み込む
const ROOTS : Array[String] = [
	"res://stage1.tscn",
	"res://stage2.tscn",
	"res://stage3.tscn",
	"res://stage4.tscn",
	"res://GameScene/Enemy/SECRET/union_boss.tscn", # 裏ボス(エンディングで、名前で読み込む)
	"res://GameScene/Ending/staff_roll.tscn",
]

static var _held : Dictionary = {}       # path → Resource(持ち続ける)
static var _queue : PackedStringArray = []
static var _total : int = 0
static var _warm : bool = false

static func is_warm() -> bool:
	return _warm

## 読み込む順番を作る
static func begin() -> void:
	_queue.clear()
	var seen := {}
	for root in ROOTS:
		_collect(root, seen)
	_total = _queue.size()

## 依存されるものが先に来るように並べる(後で読む親は、もう読んだものを使うので速い)
static func _collect(path : String, seen : Dictionary) -> void:
	if seen.has(path) or not ResourceLoader.exists(path):
		return
	if path.get_extension() in ["gd", "gdshader", "gdshaderinc"]:
		return # スクリプトとシェーダーは、使うシーンと一緒に読み込まれる(名前で別に読むと、同じクラスが2つできることがある)
	seen[path] = true
	for dep in ResourceLoader.get_dependencies(path):
		var dep_path : String = dep.get_slice("::", 2) if dep.contains("::") else dep
		if dep_path.begins_with("uid://"):
			var id := ResourceUID.text_to_id(dep_path)
			dep_path = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
		if dep_path != "":
			_collect(dep_path, seen)
	_queue.append(path)

## usec マイクロ秒ぶん読み込みを進める。進み具合(0〜1)を返す。全部読み終わったら 1
static func step(usec : int) -> float:
	var start := Time.get_ticks_usec()
	while not _queue.is_empty() and Time.get_ticks_usec() - start < usec:
		var path := _queue[0]
		_queue.remove_at(0)
		if _held.has(path):
			continue
		var res := ResourceLoader.load(path)
		if res:
			_held[path] = res
	if _queue.is_empty():
		_warm = true
		return 1.0
	return 1.0 - float(_queue.size()) / maxf(_total, 1)

## 持っているリソース(シーンなら、すぐに切り替えに使える)
static func get_cached(path : String) -> Resource:
	return _held.get(path)
