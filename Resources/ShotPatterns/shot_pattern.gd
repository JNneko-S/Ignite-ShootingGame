@tool
extends Resource
class_name ShotPattern
## 敵の弾幕1種類分の設定。.tres で保存して EnemyShooter に登録する。
## 角度は度。0 = 真下(敵の進行方向が下向きの想定)、正の値は反時計回り。

enum TimingUnit {
	SECONDS, ## タイミングを秒で数える(雑魚敵など)
	BEATS,   ## タイミングを拍で数える(BGM に合わせるボス戦。BeatChart のテンポを使う)
}

## null のときは EnemyShooter の default_bullet_scene を使う。
## 弾の見た目は、誰が撃つかではなく、弾の動き(性質)で選ぶ。ボスも同じルールに従う。
## 上から順に見て、最初に当てはまるものを使う:
##    1. 分裂弾   E_Spiky_Split         … あとで割れる(Split Pattern と Split Time がある)。割れたあとの弾は、その性質で選び直す
##    2. 撃ち返し E_Purple_Revenge      … RevengeShooter が撃つ弾
##    3. 大玉     E_Massive_Light_Green … イグナイトの狙いどころ(引きつけて焼くと得する弾)。動きに関係なく、これを使う
##    4. 止まる弾 E_Pink_Medium         … 動きの途中で止まる・漂う(Target Speed が 20 以下になる段階がある)
##    5. 減速弾   E_Indigo_Slow         … 遅くなるが止まらない(Target Speed が 8 割未満に下がる / Bullet Accel が負)
##    6. 曲がる弾 E_Green_Curve         … 曲がる(Angular Velocity がある)
##    7. 狙い弾   E_Magenta_Aim         … 自機を狙う(Aim At Player がオンで、広がり 60 度以下、回転しない)。
##                                         いちばん見えないと困る弾なので、加速していてもこちら(ボスの狙い弾も同じ)
##    8. 加速弾   E_medium_flamy        … 速くなる(Bullet Accel が正 / Target Speed が 1.2 倍より上がる)
##    9. 雨弾     E_Bermuda             … 真下へ落とすだけ(狙わない・真下・広がりなし・回転しない)
##   10. 拡散弾   E_Blue_Cian           … 全方位・扇・回転・ばらつき(見せかけの弾)
##   11. 通常弾   E_Red_Normal          … どれにも当てはまらない弾
## 速い弾ほどアニメはゆっくり、遅い弾ほど速くすると見やすい
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
## 撃つこの秒数前から、弾の飛ぶ向きに予告線を出す(いつも秒で数える)。0 なら出さない。
## 予告線は撃つ瞬間まで自機を追い、撃つ向きと同じになる。
## 撃つ前の待ち(Start Delay / Pause)がこれより短いときは、予告のぶんだけ長く待つ
@export var warning_time : float = 0.0

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

@export_group("分裂")
## 撃ってからこの秒数で、弾が割れて Split Pattern の弾になる。0 なら割れない
@export var split_time : float = 0.0
## 割れたあとの弾幕。使うのは「弾の並べ方」「列弾」「ばらつき」「弾の性質」「弾の動き」と、その「分裂」(割れた弾がまた割れる。3段階まで)。
## タイミングは使わない(割れた瞬間に1回だけ出る)。弾シーンが空なら、割れる前の弾と同じ見た目になる
@export var split_pattern : ShotPattern
## オンなら、割れた弾幕の向きの基準を、割れる前の弾の進む向きにする(Split Pattern の Aim At Player がオフのとき)。
## オフなら、基準は真下。Aim At Player がオンなら、割れた場所から自機を狙う
@export var split_follow_direction : bool = true
