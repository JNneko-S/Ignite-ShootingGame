@tool
extends Resource
class_name ShooterPhase
## 砲口(EnemyShooter)の、ボスの段階1つ分の弾幕。EnemyShooter の Phases に、段階の順(第一形態から)に並べる。
## 弾の見た目は、入れた ShotPattern の Bullet Scene で決まる。

## 同時に撃つ弾幕(それぞれ Loop の設定どおりに繰り返す)
@export var patterns : Array[ShotPattern] = []
## 順番に撃つ弾幕(1つ撃ち終わったら Pause だけ待って次へ。最後まで行ったら最初に戻る)
@export var sequence : Array[ShotPattern] = []

@export_group("ANOTHER")
## オンなら、ANOTHER のときは、Patterns / Sequence の代わりに、下の2つを撃つ(空なら、その段階は撃たない)
@export var another_replace : bool = false
@export var another_patterns : Array[ShotPattern] = []
@export var another_sequence : Array[ShotPattern] = []
@export_group("二周目")
## オンなら、二周目(RunConfig.loop が 2 以上)のときは、Patterns / Sequence の代わりに、下の2つを撃つ(難易度の差し替えより先)
@export var loop2_replace : bool = false
@export var loop2_patterns : Array[ShotPattern] = []
@export var loop2_sequence : Array[ShotPattern] = []
@export_group("EASY")
## EASY のときは、Patterns の代わりに、こちらを撃つ(空なら、差し替えない)
@export var easy_patterns : Array[ShotPattern] = []
## EASY のときは、Sequence の代わりに、こちらを撃つ(空なら、差し替えない)
@export var easy_sequence : Array[ShotPattern] = []

## この難易度で撃つ、同時に撃つ弾幕
func patterns_for_difficulty() -> Array[ShotPattern]:
	if loop2_replace and RunConfig.loop >= 2:
		return loop2_patterns
	if another_replace and HazardRank.active:
		return another_patterns
	return easy_patterns if DifficultyTuning.is_easy() and not easy_patterns.is_empty() else patterns

## この難易度で撃つ、順番に撃つ弾幕
func sequence_for_difficulty() -> Array[ShotPattern]:
	if loop2_replace and RunConfig.loop >= 2:
		return loop2_sequence
	if another_replace and HazardRank.active:
		return another_sequence
	return easy_sequence if DifficultyTuning.is_easy() and not easy_sequence.is_empty() else sequence
