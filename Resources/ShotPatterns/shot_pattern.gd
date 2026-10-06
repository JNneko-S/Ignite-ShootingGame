extends Resource
class_name ShotPattern
## 敵の弾幕1種類分の設定。.tres で保存して EnemyShooter に登録する。
## 角度は度。0 = 真下(敵の進行方向が下向きの想定)、正の値は反時計回り。

## null のときは EnemyShooter の default_bullet_scene を使う
@export var bullet_scene : PackedScene

@export_group("タイミング")
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
@export var aim_at_player : bool = false
@export var base_angle : float = 0.0
## 1発撃つごとに基準角度を回転させる量。渦巻き弾幕になる
@export var rotate_per_shot : float = 0.0
## 渦巻きの回転方向を、この発射数ごとに反転させる(0なら反転しない)。
## 洗濯機弾幕を作るときに使う。例: 25 なら、25発ごとに右回り⇔左回りが切り替わる
@export var reverse_every_shots : int = 0

@export_group("弾の性質")
@export var bullet_speed : float = 250.0
## 加速度(px/秒²)。マイナスで減速
@export var bullet_accel : float = 0.0
@export var damage : int = 1.0
