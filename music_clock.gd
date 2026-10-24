extends AudioStreamPlayer
class_name MusicClock
## BGM を鳴らして、曲の「今どこか」(秒・拍・小節)を正確に教える AudioStreamPlayer。
## ステージのシーンの BGM 用 AudioStreamPlayer に、このスクリプトをアタッチする。
## BeatConductor(ボスの譜面)が、これを探して、曲に合わせて弾を撃つ。
##
## 曲の位置は、音声の再生位置から計算する(フレームの時間を足していく方法と違い、ずれがたまらない)。
## ループする曲は、ループしても時間が戻らない(2周目は、曲の長さの分だけ先の時間になる)。

## 拍の頭で出る(0 から数える)
signal beat(index : int)
## 小節の頭で出る(0 から数える)
signal bar(index : int)

## テンポ(1分あたりの拍数)
@export var bpm : float = 120.0
## 曲の最初の拍(1小節目の1拍目)が鳴る位置(秒)。曲の頭に無音やイントロの前ノリがあるときに使う
@export var first_beat_offset : float = 0.0
@export var beats_per_bar : int = 4

var _loops : int = 0
var _last_position : float = 0.0
var _last_beat : int = -1

func _ready() -> void:
	add_to_group("music_clock")

## 編集中のシーンや、実行中のシーンから MusicClock を探す
static func find_in(tree : SceneTree) -> MusicClock:
	return tree.get_first_node_in_group("music_clock") as MusicClock if tree else null

## 曲を差し替えて、頭から鳴らす(ボスの曲など)
func play_music(music : AudioStream, new_bpm : float, offset : float, new_beats_per_bar : int) -> void:
	stream = music
	bpm = new_bpm
	first_beat_offset = offset
	beats_per_bar = new_beats_per_bar
	_loops = 0
	_last_position = 0.0
	_last_beat = -1
	play()

## 曲の頭からの秒数(ループした分も足す)。音声の出力の遅れも考える
func song_time() -> float:
	if not playing:
		return _loops * _stream_length() + _last_position
	var position := get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	position = maxf(position, 0.0)
	if position < _last_position - 0.5:
		_loops += 1 # 曲がループした
	_last_position = position
	return _loops * _stream_length() + position

## 1小節目の1拍目からの拍数(小数あり)
func song_beat() -> float:
	return (song_time() - first_beat_offset) / seconds_per_beat()

func seconds_per_beat() -> float:
	return 60.0 / maxf(bpm, 1.0)

func _process(_delta : float) -> void:
	if not playing:
		return
	var current := floori(song_beat())
	if current != _last_beat and current >= 0:
		_last_beat = current
		beat.emit(current)
		if current % maxi(beats_per_bar, 1) == 0:
			bar.emit(current / maxi(beats_per_bar, 1))

func _stream_length() -> float:
	return stream.get_length() if stream else 0.0
