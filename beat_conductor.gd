extends Node
class_name BeatConductor
## ボスの弾幕を、BGM のテンポに合わせて撃たせる指揮役。ボスのシーンに子ノードとして置く。
## Chart(BeatChart)のとおりに、ボスの EnemyShooter を撃たせる(EnemyShooter 自身の Patterns は使わない)。
##
## 使い方:
##   1. BeatChart(.tres)を作り、テンポ・曲・譜面(BeatCue)を並べる
##   2. ボスのシーンに Node を追加して、このスクリプトをアタッチし、Chart に割り当てる
##   3. ステージのシーンの BGM の AudioStreamPlayer に、MusicClock をアタッチしておく
##
## 時間は MusicClock の曲の再生位置から取る(ずれがたまらない)。MusicClock がなければ自分で作る。

@export var chart : BeatChart
## true なら、出現したときに始める。false なら start() を呼ぶまで撃たない
@export var autostart : bool = true
@export var debug_log : bool = false

var _clock : MusicClock
var _schedule : Array[Dictionary] = []
## 譜面の時刻 0 が、曲の頭から何秒の位置か(今の曲に合わせるとき、次の小節の頭になる)
var _chart_origin : float = 0.0
var _last_time : float = 0.0
var _running : bool = false
## 砲口の名前 → EnemyShooter
var _shooters : Dictionary = {}

func _ready() -> void:
	if chart == null:
		push_warning("BeatConductor: Chart(BeatChart)が設定されていません")
		return
	var owner_node := get_parent()
	for node in owner_node.find_children("*", "", true, false):
		if node is EnemyShooter:
			_shooters[String(node.name)] = node
			node.stop() # Patterns で撃つのを止める(弾は譜面のとおりに撃つ)
	if autostart:
		start.call_deferred()

func start() -> void:
	if chart == null:
		return
	_schedule = chart.build_schedule()
	_clock = MusicClock.find_in(get_tree())
	if _clock == null:
		_clock = MusicClock.new()
		add_child(_clock)
	if chart.music:
		_clock.play_music(chart.music, chart.bpm, chart.first_beat_offset, chart.beats_per_bar)
		_chart_origin = 0.0
	elif _clock.playing:
		# 今の曲の、次の小節の頭から始める
		var bar_seconds := chart.seconds_per_beat() * chart.beats_per_bar
		var now := _clock.song_time() - chart.first_beat_offset
		_chart_origin = ceilf(now / bar_seconds) * bar_seconds
	else:
		push_warning("BeatConductor: 曲がありません。Chart の Music を設定するか、BGM に MusicClock を付けてください")
		return
	_last_time = -INF
	_running = true
	if debug_log:
		print("[BeatConductor] 開始 発射%d回 origin=%.2f" % [_schedule.size(), _chart_origin])

func stop() -> void:
	_running = false

## 譜面の今の時刻(曲の頭からの秒数。今の曲に合わせるときは、合わせた小節の頭が 0 + offset)
func chart_time() -> float:
	return _clock.song_time() - _chart_origin if _clock else 0.0

func _process(_delta : float) -> void:
	if not _running:
		return
	var now := chart_time()
	if now < _last_time:
		if _last_time - now < 0.1:
			return # 再生位置の計算の揺れで、少しだけ戻った
		_last_time = now - 0.0001 # 大きく戻った(曲を頭から鳴らし直した)
	for shot in chart.shots_between(_schedule, _last_time, now):
		_fire(shot)
	_last_time = now

func _fire(shot : Dictionary) -> void:
	var target : String = shot["shooter"]
	if target == "":
		var excluded : PackedStringArray = shot["except"]
		for shooter_name in _shooters:
			if not excluded.has(shooter_name):
				_shooters[shooter_name].fire_scheduled(shot["pattern"], shot["index"])
	elif _shooters.has(target):
		_shooters[target].fire_scheduled(shot["pattern"], shot["index"])
	elif debug_log:
		print("[BeatConductor] 砲口 %s が見つかりません" % target)
