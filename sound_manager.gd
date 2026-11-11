extends Node
## 効果音を鳴らす(自動読み込み: SoundManager)。
##
## 効果音は、シーンに置いた AudioStreamPlayer のノードで設定する(音・音量・高さ・バスはインスペクタで決める。
## エディタでは、ノードの Playing をオンにすると試聴できる)。部品は、そのノードを SoundManager.play(ノード) に渡す。
## SoundManager は、ノードの設定を自分の再生用ノードに写して鳴らすので:
##   ・同じ音が重なっても途切れない
##   ・鳴らしたノードの持ち主が消えても(敵が倒れた瞬間など)、最後まで鳴る

## 同時に鳴らせる効果音の数
const VOICES : int = 16
## 効果音を流すバス(ノードのバスが Master のとき)。なければ Master
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
		add_child(player)
		_players.append(player)

## node(シーンに置いた AudioStreamPlayer)の設定で鳴らす。
## pitch_scale は高さの倍率(ノードの Pitch Scale に掛ける)、volume_offset_db は音量のずらし(ノードの Volume Db に足す)
func play(node : AudioStreamPlayer, pitch_scale : float = 1.0, volume_offset_db : float = 0.0) -> void:
	if not is_instance_valid(node) or node.stream == null:
		return
	_start(_free_player(), node.stream, node.volume_db + volume_offset_db, node.pitch_scale * pitch_scale, node.bus)

## node の設定で、決まった名前の専用の再生ノードで鳴らす。前の音が鳴っていたら止めて、頭から鳴らし直す。
## 自機のショットのように、何度も続けて鳴る音に使う(他の効果音の枠を使い切らない)
func play_on_channel(channel : StringName, node : AudioStreamPlayer, pitch_scale : float = 1.0, volume_offset_db : float = 0.0) -> void:
	if not is_instance_valid(node) or node.stream == null:
		return
	var player : AudioStreamPlayer = _channels.get(channel)
	if player == null:
		player = AudioStreamPlayer.new()
		add_child(player)
		_channels[channel] = player
	_start(player, node.stream, node.volume_db + volume_offset_db, node.pitch_scale * pitch_scale, node.bus)

## node の今の設定を写し取る(あとで play_copy で鳴らす)。ノードが消えたあとに鳴らす音(続けて起こる爆発など)に使う
func copy_of(node : AudioStreamPlayer) -> Dictionary:
	if not is_instance_valid(node) or node.stream == null:
		return {}
	return {"stream": node.stream, "volume_db": node.volume_db, "pitch_scale": node.pitch_scale, "bus": node.bus}

## copy_of で写し取った設定で鳴らす
func play_copy(copy : Dictionary, pitch_scale : float = 1.0, volume_offset_db : float = 0.0) -> void:
	if copy.is_empty():
		return
	_start(_free_player(), copy["stream"], copy["volume_db"] + volume_offset_db, copy["pitch_scale"] * pitch_scale, copy["bus"])

func _start(player : AudioStreamPlayer, stream : AudioStream, volume_db : float, pitch : float, bus : StringName) -> void:
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch, 0.01)
	player.bus = _bus if bus == &"Master" else bus
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
