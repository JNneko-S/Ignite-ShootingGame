extends Node
class_name ItemDrop
## 倒されたとき(壊れたとき)にアイテムを出す部品。持ち主の子に置いて、drop() を呼ぶ。
## 1つの持ち主に、いくつ置いてもよい(種類ごとに確率を変えられる)。

## 出すアイテムのシーン。空なら出さない
@export var item_scene : PackedScene
## 出す確率(0〜1)
@export_range(0.0, 1.0, 0.05) var chance : float = 1.0

## at の位置(画面の座標)にアイテムを出す。物理の処理中に呼ばれてもよい
func drop(at : Vector2) -> void:
	if item_scene == null or randf() > chance:
		return
	var item := item_scene.instantiate()
	if item is Node2D:
		item.position = at # シーンの直下に足すので、位置 = 画面(ワールド)の座標
	get_tree().current_scene.add_child.call_deferred(item)

## node の子にある ItemDrop を、すべて鳴らす
static func drop_all(node : Node, at : Vector2) -> void:
	for child in node.get_children():
		if child is ItemDrop:
			child.drop(at)
