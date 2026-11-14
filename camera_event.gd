@tool
extends StageEvent
class_name StageCameraEvent
## カメラ(StageCamera)の動き方を変える。描画範囲を左・中央・右へ移すときに使う。
##   FOLLOW: 自機に付いていく(道中、ボス戦)
##   LOCK:   Lane の画面へ移って止まる(中ボス戦。自機もその画面の中だけ)
##   LOOK:   Lane の画面へ一時的に向いて、Hold 秒たったら前の動き方に戻る

@export var mode : StageCamera.Mode = StageCamera.Mode.LOCK
## レーン(StageCamera の Lanes の番号。ステージ2は 0 = 左、1 = 中央、2 = 右)
@export var lane : int = 1
## 移るのにかける時間(秒)。負なら StageCamera の Move Time
@export var move_time : float = -1.0
## LOOK のとき、向いたままでいる時間(秒)
@export var hold : float = 2.0

func execute(runner : StageRunner, _unit_index : int) -> void:
	var camera := StageCamera.of(runner)
	if camera == null:
		push_warning("StageCameraEvent: シーンに StageCamera がありません")
		return
	if mode == StageCamera.Mode.LOOK:
		camera.look(camera.lane_x(lane), hold, move_time)
	else:
		camera.change(mode, lane, move_time)
