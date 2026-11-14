@tool
extends Resource
class_name BossPhase
## ボスの段階1つ分。BossPhaseController(ボスのシーン)か、SpawnEvent の Phases に、HPの多い順に並べる。
## HPの割合が hp_ratio 以下になったら、この段階に切り替わる(最初の段階は 1.0)。
## 砲口ごとの弾幕は、各 EnemyShooter の Phases に入れる。
## Phases を持たない砲口には、ここの Patterns が入る(全ての砲口に同じもの)。

## この割合以下になったら、この段階になる。例: 1.0 / 0.66 / 0.33
@export_range(0.0, 1.0, 0.01) var hp_ratio : float = 1.0
## Phases を持たない砲口に入る弾幕(同時に撃つ)
@export var patterns : Array[ShotPattern] = []
## 切り替えるときに、画面内の敵弾を消す(段階の区切りを分かりやすくする)
@export var clear_bullets : bool = true
## この段階のボスの色(白なら元の色)。発狂などを、見た目で分かるようにする
@export var boss_modulate : Color = Color.WHITE

@export_group("呼び寄せ(援護)")
## この段階のあいだに出すもの(SpawnEvent / TrainEvent など。Time は呼び寄せてからの秒数)
@export var summons : Array[StageEvent] = []
## HPの割合がこれ以下になったら呼び寄せる。この段階の Hp Ratio 以上なら、段階に入ったときに呼ぶ。
## 例: 第一形態(Hp Ratio 1.0)で 0.83 なら、第一形態のHPが半分になったとき
@export_range(0.0, 1.0, 0.01) var summon_hp_ratio : float = 1.0
## 0 以上なら、呼び寄せたときに、カメラ(StageCamera)をこのレーンへ一時的に向ける(0 = 左、1 = 中央、2 = 右)。
## そのとき、画面の弾を消し、敵は少し撃たず、自機はその場に止まる(カメラだけが向く)
@export var summon_look_lane : int = -1
## カメラを向けている時間(秒)
@export var summon_look_hold : float = 3.5
