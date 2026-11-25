extends Node2D
class_name HPComponent

@export var max_hp : int = 1
@export var hp : int = 1 : set = _set_hp #setterは変数を使うときに呼び出される関数

signal hp_changed #hpが変わったときに呼び出される
signal is_dead #自身が死んだ時に呼び出される

var _dead : bool = false #死亡済みか(is_dead を二重に出さないためのフラグ)

## カウンター大技のあいだ true: ふつうのダメージは 1 に固定する(Counter Pass のときだけ、そのまま入る)
var damage_lock : bool = false
## 次の1回だけ、Damage Lock を素通りする(カウンター弾を返して当てたとき)
var counter_pass : bool = false
## 0 より大きければ、HPはこれより下がらない(倒れる直前で止める)。下がろうとしたら floor_reached を出す
var hp_floor : int = 0
signal floor_reached

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
	if damage_lock and not counter_pass:
		amount = mini(amount, 1)
	counter_pass = false
	if hp_floor > 0 and hp - amount < hp_floor:
		hp = hp_floor
		floor_reached.emit()
		return
	hp -= amount
