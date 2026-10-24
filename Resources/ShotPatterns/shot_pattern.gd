@tool
extends Resource
class_name ShotPattern
## 敵の弾幕1種類分の設定。.tres で保存して EnemyShooter に登録する。
## 角度は度。0 = 真下(敵の進行方向が下向きの想定)、正の値は反時計回り。

enum TimingUnit {
	SECONDS, ## タイミングを秒で数える(雑魚敵など)
	BEATS,   ## タイミングを拍で数える(BGM に合わせるボス戦。BeatChart のテンポを使う)
}

## null のときは EnemyShooter の default_bullet_scene を使う
@export var bullet_scene : PackedScene

@export_group("タイミング")
## Start Delay / Interval / Pause を、秒で数えるか拍で数えるか。
## 拍なら、例えば Interval 0.5 = 8分音符ごと、Pause 2 = 2拍休み
@export var timing_unit : TimingUnit = TimingUnit.SECONDS
## 出現してから撃ち始めるまでの待ち時間(秒)
@export var start_delay : float = 0.5
## 連射(バースト)1回あたりの発射数。1なら単発
@export var shot_count : int = 1
## バースト内の発射間隔(秒)
@export var interval : float = 0.1
## true なら、バースト終了後に pause 秒待ってまた撃つ。false なら1回だけ
@export var loop : bool = true
## バースト間の待ち時間(秒)
@export var pause : float = 1.5

@export_group("弾の並べ方")
## 1回の発射で出す弾の数
@export var bullet_count : int = 1
## 弾を広げる角度の合計。360以上なら全方位(リング状)
@export var spread_angle : float = 0.0
## true なら自機に向けて撃つ(base_angle は自機方向からのずれになる)
@export var aim_at_player : bool = true
@export var base_angle : float = 0.0
## 1発撃つごとに基準角度を回転させる量。渦巻き弾幕になる
@export var rotate_per_shot : float = 0.0
## 渦巻きの回転方向を、この発射数ごとに反転させる(0なら反転しない)。
## 洗濯機弾幕を作るときに使う。例: 25 なら、25発ごとに右回り⇔左回りが切り替わる
@export var reverse_every_shots : int = 0
## 回転量の加速(度/発²)。渦巻きの回転が、だんだん速く(マイナスなら遅く)なる
@export var rotate_accel : float = 0.0
## 基準角度を、正弦波で左右に揺らす大きさ(度)。0 なら揺らさない
@export var angle_wave_amplitude : float = 0.0
## 揺れ1往復にかける発射数
@export var angle_wave_shots : int = 20
## true なら、自機狙いの向きをバーストの最初の1発で決めて、バーストの間は固定する
@export var aim_once_per_burst : bool = false
## 弾を、砲口からこの距離(px)の円周上に出す。0 なら砲口から
@export var spawn_radius : float = 0.0

@export_group("列弾")
## 同じ向きに、速さの違う弾を何発ずつ重ねるか(1 なら重ねない)
@export var line_count : int = 1
## 列の1発ごとに、速さ(Motion の速度も含む)を何倍ずつ増やすか。例: 0.15 なら ×1.0, ×1.15, ×1.3 …
@export var line_speed_ratio : float = 0.15

@export_group("ばらつき")
## 角度のばらつき(±度)
@export var random_angle : float = 0.0
## 速さのばらつき(±割合)。例: 0.1 なら ×0.9〜×1.1
@export var random_speed_ratio : float = 0.0
## ばらつきの種。プレビューとゲームで、同じばらつき方になる
@export var random_seed : int = 0

@export_group("弾の性質")
## 撃った瞬間の速さ(px/秒)
@export var bullet_speed : float = 250.0
## 加速度(px/秒²)。マイナスで減速(止まったらそこで止まる)。Motion を使うときは無視される
@export var bullet_accel : float = 0.0
@export var damage : float = 1.0

@export_group("弾の動き")
## 撃ったあとの動きを、区間ごとに並べる(速度のイージング、向きの変更、曲がり)。
## 空なら、Bullet Speed と Bullet Accel だけで動く
@export var motion : Array[BulletStep] = []
