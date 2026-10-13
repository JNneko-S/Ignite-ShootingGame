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
## 待機イベントで「この敵が全滅するまで待つ」と指定するための名前(例: midboss, boss)
@export var tag : String = ""

@export_group("ボス")
## オンにすると、この敵のHPゲージ(BossGauge)が出る
@export var is_boss : bool = false
## ゲージの上に出す名前
@export var boss_name : String = ""
## フェーズの目印にするHPの割合。例: [0.66, 0.33] なら、HPが2/3と1/3を切ったときに目印を割る
@export var boss_phase_thresholds : Array[float] = []

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

func unit_count() -> int:
	return maxi(count, 1)

func unit_time(unit_index : int) -> float:
	return time + interval * unit_index

func execute(runner : StageRunner, unit_index : int) -> void:
	runner.spawn(self, unit_index)
