@tool
extends Resource
class_name BeatCue
## ボスの譜面(BeatChart)の1行。「何小節目の何拍目から、どの砲口で、どの弾幕を、何拍のあいだ撃つか」。
## Pattern を空にすると、その砲口を止める(休符)。

## 始まる小節(1 から数える)
@export var bar : int = 1
## 始まる拍(1 から数える)。1.5 なら1拍目の裏(8分音符ぶん後ろ)
@export var beat : float = 1.0
## 撃つ砲口(ボスの EnemyShooter のノード名)。空なら全ての砲口
@export var shooter : String = ""
## 撃つ弾幕。Timing Unit を BEATS にすると、譜面のテンポに合う。空なら止める
@export var pattern : ShotPattern
## 撃つ長さ(拍)。0 なら、同じ砲口の次の行が始まるまで
@export var length_beats : float = 0.0
## エディタに表示するメモ(例: サビ、Aメロ)
@export var note : String = ""
