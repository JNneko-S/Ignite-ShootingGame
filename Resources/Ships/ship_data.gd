extends Resource
class_name ShipData
## 出撃できる機体1つ分の情報。機体選択の画面(ShipSelect)の Ships に並べる。.tres で保存する。

## 名前(電光掲示板と、選択の輪の下に出る。英大文字で)
@export var ship_name : String = "PHOENIX"
## 機体説明の欄の、見出しの下に出る短い説明(1行)
@export var subtitle : String = ""
## 機体説明の欄に出す説明(改行してよい)
@export_multiline var description : String = ""
## プレビューと、選択の輪の中に出す絵。横に何コマ並んでいるかと、使うコマ
@export var texture : Texture2D
@export var hframes : int = 1
@export var frame : int = 0
## プレビューでの大きさの倍率と、選択の輪の中での大きさの倍率
@export var preview_scale : float = 1.2
@export var icon_scale : float = 0.7
## 出撃する自機のシーン(今は記録するだけ。機体が増えたら、ステージの自機と入れ替える)
@export var player_scene : PackedScene
