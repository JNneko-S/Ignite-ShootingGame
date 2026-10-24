@tool
extends Resource
class_name BeatChart
## ボス戦の譜面。BGM のテンポに合わせて、どの弾幕をいつ撃つかを並べる。
## ボスのシーンの BeatConductor に割り当てる。エディタでは BeatChartPreview で、曲を鳴らしながら確認できる。
##
## 時刻は「曲の頭からの秒数」。1小節目の1拍目 = First Beat Offset 秒。
## 行の切り替わり方:
##   ・砲口を指定した行は、同じ砲口の次の行か、次の「全砲口」の行で止まる
##   ・全砲口の行(砲口が空)は、次の全砲口の行で止まる。途中で、ある砲口だけの行が始まると、
##     その砲口だけが、そちらに切り替わる(他の砲口は撃ち続ける)
##   ・Length Beats を指定すれば、その長さで止まる

## テンポ(1分あたりの拍数)
@export var bpm : float = 150.0
## 曲の最初の拍(1小節目の1拍目)が鳴る位置(秒)
@export var first_beat_offset : float = 0.0
@export var beats_per_bar : int = 4
## ボスの曲。設定すると、ボスが出たときに頭から鳴らす。
## 空なら、今鳴っている曲(MusicClock)に合わせて、次の小節の頭から譜面を始める
@export var music : AudioStream

@export_group("ループ")
## 0 より大きければ、Loop End Bar の頭に来たら、Loop Start Bar の頭に戻って繰り返す
## (曲のループ位置と合わせる)
@export var loop_start_bar : int = 0
@export var loop_end_bar : int = 0

@export_group("譜面")
@export var cues : Array[BeatCue] = []

## ループしない譜面で、最後の行が終わりを持たないとき、ここまで撃つ(秒)
const OPEN_END_SECONDS : float = 600.0

func seconds_per_beat() -> float:
	return 60.0 / maxf(bpm, 1.0)

## 小節・拍(どちらも 1 から)を、曲の頭からの秒数にする
func bar_beat_to_time(bar : int, beat : float) -> float:
	return first_beat_offset + ((bar - 1) * beats_per_bar + (beat - 1.0)) * seconds_per_beat()

## 曲の頭からの秒数を、{"bar": 小節, "beat": 拍} にする(どちらも 1 から)
func time_to_bar_beat(time : float) -> Dictionary:
	var beats := (time - first_beat_offset) / seconds_per_beat()
	var bar := floori(beats / beats_per_bar)
	return {"bar": bar + 1, "beat": beats - bar * beats_per_bar + 1.0}

func is_looping() -> bool:
	return loop_start_bar > 0 and loop_end_bar > loop_start_bar

func loop_start_time() -> float:
	return bar_beat_to_time(loop_start_bar, 1.0)

func loop_end_time() -> float:
	return bar_beat_to_time(loop_end_bar, 1.0)

## 行(cue)ごとの、始まりと終わりの秒数。{"cue", "start", "end", "overrides"} を、始まりの順に返す。
## overrides は、全砲口の行のときだけ、途中から別の行に切り替わる砲口の {"shooter", "from"} の並び
func cue_windows() -> Array[Dictionary]:
	var sorted : Array[BeatCue] = []
	for cue in cues:
		if cue != null:
			sorted.append(cue)
	sorted.sort_custom(func(a : BeatCue, b : BeatCue) -> bool:
		return bar_beat_to_time(a.bar, a.beat) < bar_beat_to_time(b.bar, b.beat))
	var horizon := loop_end_time() if is_looping() else OPEN_END_SECONDS
	var windows : Array[Dictionary] = []
	for i in sorted.size():
		var cue := sorted[i]
		var start := bar_beat_to_time(cue.bar, cue.beat)
		var end := horizon
		var overrides : Array[Dictionary] = []
		for j in range(i + 1, sorted.size()):
			var later := sorted[j]
			if later.shooter == "" or later.shooter == cue.shooter:
				end = bar_beat_to_time(later.bar, later.beat)
				break
			if cue.shooter == "":
				overrides.append({"shooter": later.shooter, "from": bar_beat_to_time(later.bar, later.beat)})
		if cue.length_beats > 0.0:
			end = minf(end, start + cue.length_beats * seconds_per_beat())
		windows.append({"cue": cue, "start": start, "end": minf(end, horizon), "overrides": overrides})
	return windows

## 譜面の全ての発射を、時刻の順に並べた表(ループするなら、1周目のループの終わりまで)。
## 1発ごとに {"time": 秒, "cue": BeatCue, "pattern": ShotPattern, "shooter": 砲口の名前,
## "except": 撃たない砲口の名前(全砲口の行で、別の行に切り替わった砲口), "index": 何発目か}
func build_schedule() -> Array[Dictionary]:
	var schedule : Array[Dictionary] = []
	var spb := seconds_per_beat()
	for window in cue_windows():
		var cue : BeatCue = window["cue"]
		if cue.pattern == null:
			continue
		var start : float = window["start"]
		var length : float = window["end"] - start
		var overrides : Array[Dictionary] = window["overrides"]
		for shot in ShotMath.shot_times(cue.pattern, length - 0.0001, spb):
			var time : float = start + shot["time"]
			var excluded := PackedStringArray()
			for override in overrides:
				if override["from"] <= time + 0.0001:
					excluded.append(override["shooter"])
			schedule.append({"time": time, "cue": cue, "pattern": cue.pattern,
					"shooter": cue.shooter, "except": excluded, "index": shot["index"]})
	schedule.sort_custom(func(a : Dictionary, b : Dictionary) -> bool: return a["time"] < b["time"])
	return schedule

## from より後で、to 以下の時刻の発射を返す(ループも考える)。schedule は build_schedule の結果。
## ループした分は、"time" をずらして返す
func shots_between(schedule : Array[Dictionary], from : float, to : float) -> Array[Dictionary]:
	var result : Array[Dictionary] = []
	if to <= from:
		return result
	if not is_looping():
		_collect(schedule, from, to, 0.0, result)
		return result
	var loop_start := loop_start_time()
	var loop_length := loop_end_time() - loop_start
	# 1周目(ループの終わりまで)
	_collect(schedule, from, minf(to, loop_start + loop_length), 0.0, result)
	# 2周目から: ループの区間だけを、ずらして使う
	if to > loop_start + loop_length:
		var first := maxi(floori((maxf(from, loop_start) - loop_start) / loop_length), 1)
		var last := floori((to - loop_start) / loop_length)
		for k in range(first, last + 1):
			var shift := loop_length * k
			# ループの頭ちょうどの発射も含める(_collect は from ちょうどを含まない)
			var lower := from - shift if from - shift >= loop_start else loop_start - 0.0001
			_collect(schedule, lower, minf(to - shift, loop_start + loop_length), shift, result)
	return result

func _collect(schedule : Array[Dictionary], from : float, to : float, shift : float, result : Array[Dictionary]) -> void:
	if to <= from:
		return
	# 時刻の順に並んでいるので、始まりを二分探索で探す
	var lo := 0
	var hi := schedule.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if schedule[mid]["time"] <= from:
			lo = mid + 1
		else:
			hi = mid
	for i in range(lo, schedule.size()):
		var shot : Dictionary = schedule[i]
		if shot["time"] > to:
			break
		if shift == 0.0:
			result.append(shot)
		else:
			var copy := shot.duplicate()
			copy["time"] = shot["time"] + shift
			result.append(copy)
