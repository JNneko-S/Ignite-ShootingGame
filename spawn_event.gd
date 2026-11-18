@tool
extends StageEvent
class_name SpawnEvent
## 敵を出現させる。同じ敵を count 体、interval 秒おきに出せる(隊列)。
## 移動・弾幕・HP は、敵シーンの設定をそのまま使うか、ここで上書きできる。

@export_group("敵")
## 出現させる敵のシーン(ルートが enemy.gd の CharacterBody2D)
@export var enemy_scene : PackedScene
## 空なら、敵シーンの Pattern を使う
@export var move_pattern : MovePattern
## 空でなければ、敵の EnemyShooter の Patterns をこれで置き換える
@export var shot_patterns : Array[ShotPattern] = []
## 0 より大きければ、敵のHPをこの値にする
@export var hp_override : int = 0
## 0 以上なら、この敵がパワーアップを落とす確率(0〜1)を、敵のシーンの値の代わりに使う。1 なら確定で落とす。
## -1 なら、敵のシーンのまま(パワーアップを落とさない敵には効かない)
@export_range(-1.0, 1.0, 0.05) var power_drop_chance : float = -1.0
## 待機イベントで「この敵が全滅するまで待つ」と指定するための名前(例: midboss, boss)
@export var tag : String = ""

@export_group("ボス")
## オンにすると、この敵のHPゲージ(BossGauge)が出る
@export var is_boss : bool = false
## ゲージの上に出す名前
@export var boss_name : String = ""
## フェーズの目印にするHPの割合。例: [0.66, 0.33] なら、HPが2/3と1/3を切ったときに目印を割る
@export var boss_phase_thresholds : Array[float] = []
## HPの割合で切り替える弾幕(HPの多い順に並べる)。空なら切り替えない。
## 設定すると、Shot Patterns の代わりに、最初の段階の弾幕を使う
@export var phases : Array[BossPhase] = []
## オンにすると、倒したときの点を「ボスの時間ボーナス」にする(ScoreSystem の Boss Bonus を参照)。
## ステージの最後のボスでオンにする。中ボスはオフのまま(敵シーンの Score Value を使う)
@export var boss_time_bonus : bool = false

@export_group("数と並べ方")
@export var count : int = 1
## 隊列の、1体ごとの出現間隔(秒)
@export var interval : float = 0.3
## 全体のずれ(移動パターンの出現位置と目標が、この分だけずれる)
@export var offset : Vector2 = Vector2.ZERO
## 1体ごとに加算するずれ。例: (60, 0) で、横に60pxずつずらして出す
@export var offset_step : Vector2 = Vector2.ZERO
## 左右反転して動く
@export var mirror_x : bool = false
## true なら、1体おきに左右反転する(左右対称のペアになる)
@export var alternate_mirror : bool = false
## カメラが横に動くステージ(StageCamera)で、どの画面の座標として出すか。
## -1 なら今カメラに映っている画面。0 以上なら、そのレーン(0 = 左、1 = 中央、2 = 右)の画面(ボスが呼び寄せる援護など)
@export var camera_lane : int = -1
## 隊列を1体残らず倒したときのボーナス点(0 ならなし)。最後に倒した場所に「全滅 +点」と出る。
## 1体でも画面の外へ逃げたら出ない(Count が 2 以上のときだけ)
@export var formation_bonus : int = 0

@export_group("背景から出てくる")
## 0: ふつうに出る / 1: 背景から近づいてくる(小さく暗い姿から大きく濃くなって前に出る) /
## 2: 背景の下から上へ飛び去ってから、上から入り直す(BackgroundEmerge)
@export_enum("ふつう", "近づいてくる", "上へ抜けて入り直す") var emerge : int = 0
## 背景から出てくるまでの時間(秒)
@export var emerge_time : float = 1.2

@export_group("数式の飛び方")
## 設定すると、移動パターンの代わりに、この曲線(円・バラ曲線・星形など)に沿って飛ぶ。
## 何機かで出して Phase Step で曲線の上に等間隔に並べると、編隊で図形を描ける
@export var flight_curve : FlightCurve

func unit_count() -> int:
	return maxi(count, 1)

func unit_time(unit_index : int) -> float:
	return time + interval * unit_index

func execute(runner : StageRunner, unit_index : int) -> void:
	runner.spawn(self, unit_index)
