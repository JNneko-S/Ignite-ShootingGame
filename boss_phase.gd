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
