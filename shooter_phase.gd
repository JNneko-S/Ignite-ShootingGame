@tool
extends Resource
class_name ShooterPhase
## 砲口(EnemyShooter)の、ボスの段階1つ分の弾幕。EnemyShooter の Phases に、段階の順(第一形態から)に並べる。
## 弾の見た目は、入れた ShotPattern の Bullet Scene で決まる。

## 同時に撃つ弾幕(それぞれ Loop の設定どおりに繰り返す)
@export var patterns : Array[ShotPattern] = []
## 順番に撃つ弾幕(1つ撃ち終わったら Pause だけ待って次へ。最後まで行ったら最初に戻る)
@export var sequence : Array[ShotPattern] = []
