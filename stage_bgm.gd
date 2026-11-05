extends AudioStreamPlayer
class_name StageBGM
## ステージのBGM。道中の曲を流し、ボスが出たらボスの曲に切り替える。
##
## 流れ:
##   シーン開始(登場演出の始め)から、道中の曲をループで流す
##   StageSignalEvent の warning が来たら、道中の曲をフェードアウトする
##   そのあとボス(is_boss の敵)が出たら、ボスの曲をループで流す
##   (warning の前に出る is_boss の敵 = 中ボスでは、切り替えない)

## 未設定なら "stage_runner" グループから探す
@export var stage_runner : StageRunner
@export var stage_music : AudioStream
@export var boss_music : AudioStream
## この名前の StageSignalEvent が来たら、道中の曲をフェードアウトして、ボスの曲を待つ
@export var boss_signal_name : String = "warning"
## 道中の曲を消すのにかける時間(秒)
@export var fade_out_time : float = 2.0

var _base_volume : float
var _boss_pending : bool = false
var _fade : Tween

func _ready() -> void:
	_base_volume = volume_db
	_connect_runner.call_deferred() # 全ノードの準備が終わってから探す
	_play_music(stage_music)

func _connect_runner() -> void:
	if stage_runner == null:
		stage_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	if stage_runner == null:
		return
	stage_runner.stage_signal.connect(_on_stage_signal)
	stage_runner.boss_spawned.connect(_on_boss_spawned)

func _on_stage_signal(signal_name : String, _text : String) -> void:
	if signal_name != boss_signal_name:
		return
	_boss_pending = true
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", -60.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade.tween_callback(stop)

func _on_boss_spawned(_enemy : Enemy, _boss_name : String, _thresholds : Array[float]) -> void:
	if not _boss_pending:
		return # 中ボス
	_boss_pending = false
	_kill_fade()
	_play_music(boss_music)

func _play_music(music : AudioStream) -> void:
	if music == null:
		return
	if "loop" in music:
		music.loop = true # mp3 / ogg は、取り込み設定によらずループさせる
	stream = music
	volume_db = _base_volume
	play()

func _kill_fade() -> void:
	if _fade:
		_fade.kill()
