extends Node
## 効果音を鳴らす(自動読み込み: SoundManager)。どこからでも SoundManager.play_sfx(音, 音量dB) で鳴らせる。
## 再生用の AudioStreamPlayer を何個か用意して使い回すので、同じ音が重なっても途切れない。
## 鳴らしている音のノードが消えても(敵が倒れた瞬間など)、最後まで鳴る。

## 同時に鳴らせる効果音の数
const VOICES : int = 12
## 効果音を流すバス。なければ Master
const SFX_BUS : StringName = &"SFX"

var _players : Array[AudioStreamPlayer] = []
var _next : int = 0
## 専用の再生ノード(名前ごとに1つ)。連射音などに使う
var _channels : Dictionary = {}
var _bus : StringName = &"Master"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # ポーズ中も鳴らせる
	_bus = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else &"Master"
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = _bus
		add_child(player)
		_players.append(player)

## 効果音を鳴らす。volume_db は音量(dB。0 で元の大きさ、-15 で小さめ)、pitch は高さ(1.0 で元の高さ)
func play_sfx(stream : AudioStream, volume_db : float = 0.0, pitch : float = 1.0) -> void:
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

## 決まった名前の専用ノードで鳴らす。前の音が鳴っていたら止めて、頭から鳴らし直す。
## 自機のショットのように、何度も続けて鳴る音に使う(他の効果音の枠を使い切らない)
func play_channel(channel : StringName, stream : AudioStream, volume_db : float = 0.0, pitch : float = 1.0) -> void:
	if stream == null:
		return
	var player : AudioStreamPlayer = _channels.get(channel)
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = _bus
		add_child(player)
		_channels[channel] = player
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

## 空いている再生用のノード。全部鳴っていたら、一番前に鳴らしたものを止めて使う
func _free_player() -> AudioStreamPlayer:
	for i in VOICES:
		var player := _players[(_next + i) % VOICES]
		if not player.playing:
			_next = (_next + i + 1) % VOICES
			return player
	var oldest := _players[_next]
	_next = (_next + 1) % VOICES
	return oldest
