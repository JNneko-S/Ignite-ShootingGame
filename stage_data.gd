@tool
extends Resource
class_name StageData
## 1ステージ分のタイムライン。.tres で保存して、StageRunner に割り当てる。

@export var stage_name : String = "Stage 1"
## イベントの並び。順番は自由(time の小さい順に実行される)
@export var events : Array[StageEvent] = []
## 難易度 ANOTHER のとき(一周目も二周目も)、このステージの代わりに使うタイムライン。空ならこのまま。
## 一周目だけ軽くしたステージ(4面)で、ANOTHER は元のタイムラインを使うのに使う
@export var another_timeline : StageData
## 二周目(Another Round。ANOTHER 以外)で、このステージの代わりに使うタイムライン(雑魚の数・並び・弾を作り直したもの)。
## 空なら、二周目もこのタイムラインのまま
@export var second_loop : StageData
## 難易度 ANOTHER のときだけ、events に足して実行するイベント(敵の追加など)
@export var another_events : Array[StageEvent] = []
## ANOTHER で、ランクによって雑魚の撃つ頻度が上がる量の割合(1 でそのまま、0.5 なら半分だけ上がる)。
## 雑魚の弾がもともと多いステージで下げる
@export var another_zako_rate_ratio : float = 1.0
## このステージの弾幕を、難易度を何段上として扱うか(1 なら EASY は NORMAL 用、NORMAL は HARD 用の弾幕を撃つ)。
## 最終面など、集大成として一段難しくしたいステージで使う。HARD より上はない
@export_range(0, 2) var difficulty_step : int = 0
## オンなら、ANOTHER のとき、ランクに関係なく BLACK ANOTHER 用の弾幕を撃つ(最終面)
@export var another_force_black : bool = false
## true なら、HARD を選んだときも、ANOTHER と同じく敵弾の当たり判定を半分にする(最終面など、弾がとても多いステージ)
@export var small_bullet_hitbox_hard : bool = false

## EASY / NORMAL / HARD のとき、雑魚の弾幕の撃つ間(Interval・Pause・最初の待ち)に掛ける倍率。1.3 なら間が3割のびて、弾が減る。
## 道中の弾が多すぎるステージで上げる(ボス・中ボスには効かない。ANOTHER には効かない)
@export_range(0.5, 3.0, 0.05) var zako_fire_interval_scale : float = 1.0

@export_group("コンティニュー")
## 空でなければ、この Tag の待機(Wait Clear。中ボスなど)を越えたあとにゲームオーバーになってコンティニューすると、
## ステージの最初ではなく、待機を越えたところから始める(長いステージの救済。ステージをクリアすると、記録は消える)
@export var continue_checkpoint_tag : String = ""
## 記録したところから始め直したとき、選んだ難易度がこれ以下なら、子機(オプション)をこの数まで付ける(0 = EASY, 1 = NORMAL)
@export_range(-1, 3) var checkpoint_options_max_difficulty : int = 1
@export var checkpoint_options : int = 4

@export_group("体力")
## EASY / NORMAL / HARD のとき、雑魚(ボス・中ボス以外)の体力に掛ける倍率。1 ならそのまま。ANOTHER には効かない
@export_range(0.1, 2.0, 0.05) var zako_hp_scale_below_another : float = 1.0
## EASY / NORMAL / HARD のとき、中ボス・ボスの体力に掛ける倍率(部位にも掛かる)。1 ならそのまま。ANOTHER には効かない
@export_range(0.1, 2.0, 0.05) var boss_hp_scale_below_another : float = 1.0

@export_group("パワーアップ")
## オフなら、雑魚(ItemDrop を持つ敵)はパワーアップを落とさない(列車の全車両撃破で落とすステージなど)
@export var zako_power_drops : bool = true
## 空でなければ、通り過ぎる列車の全車両を壊したときに、このアイテムを落とす
@export var train_clear_power_up : PackedScene
## 列車の全車両撃破でアイテムを落としたあと、次に落とせるまでの時間(秒)。落ちる間隔をそろえるため
@export var train_clear_power_interval : float = 12.0
