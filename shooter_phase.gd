@tool
extends Resource
class_name ShooterPhase
## 砲口(EnemyShooter)の、ボスの段階1つ分の弾幕。EnemyShooter の Phases に、段階の順(第一形態から)に並べる。
## 弾の見た目は、入れた ShotPattern の Bullet Scene で決まる。

## 同時に撃つ弾幕(それぞれ Loop の設定どおりに繰り返す)
@export var patterns : Array[ShotPattern] = []
## 順番に撃つ弾幕(1つ撃ち終わったら Pause だけ待って次へ。最後まで行ったら最初に戻る)
@export var sequence : Array[ShotPattern] = []

@export_group("EASY")
## EASY のときは、Patterns の代わりに、こちらを撃つ(空なら、差し替えない)
@export var easy_patterns : Array[ShotPattern] = []
## EASY のときは、Sequence の代わりに、こちらを撃つ(空なら、差し替えない)
@export var easy_sequence : Array[ShotPattern] = []

## この難易度で撃つ、同時に撃つ弾幕
func patterns_for_difficulty() -> Array[ShotPattern]:
	return easy_patterns if DifficultyTuning.is_easy() and not easy_patterns.is_empty() else patterns

## この難易度で撃つ、順番に撃つ弾幕
func sequence_for_difficulty() -> Array[ShotPattern]:
	return easy_sequence if DifficultyTuning.is_easy() and not easy_sequence.is_empty() else sequence
