extends Node2D
class_name HPComponent

@export var max_hp : int = 1
@export var hp : int = 1 : set = _set_hp #setterは変数を使うときに呼び出される関数

signal hp_changed #hpが変わったときに呼び出される
signal is_dead #自身が死んだ時に呼び出される

var _dead : bool = false #死亡済みか(is_dead を二重に出さないためのフラグ)

func _set_hp(new_hp : int) -> void:
	if _dead:
		return
	hp = clamp(new_hp, 0, max_hp) #hpの最大値、最小値を決めている
	hp_changed.emit()
	if hp <= 0:
		_dead = true
		is_dead.emit()

func restore_hp() -> void:
	_dead = false #復活できるように死亡フラグも戻す
	hp = max_hp #初期化用の関数

func apply_damage(amount : int) -> void:
	hp -= amount
