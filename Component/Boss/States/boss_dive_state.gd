extends BossState
class_name BossDiveState
## AfterburnerDive の技(一番下まで突っ込んで、炎を噴いて上がる)を1回するステート。
## AfterburnerDive の Auto Run はオフにしておく(このステートが始める)。
## From Phase より前の段階では、何もせずに次のステートへ移る。

@export var dive : AfterburnerDive
## この段階(0 = 第一形態)から使う
@export var from_phase : int = 0
## 空でなければ、同じ名前のグループの仲間(ブラックスワンズなど)のうち、突撃するのは1機ずつにする。
## ほかの機が突撃しているあいだは、突撃せずに次のステートへ移る
@export var exclusive_group : StringName = &""

## グループごとに、今突撃している機
static var _diving : Dictionary = {}

func _run(token : int) -> void:
	if not running(token):
		return
	if is_instance_valid(dive) and phase() >= from_phase and _claim():
		await dive.perform()
		_release()
	finish(token)

## 突撃してよいか(同じグループの、ほかの機が突撃していなければ、自分の番にする)
func _claim() -> bool:
	if exclusive_group == &"":
		return true
	var holder = _diving.get(exclusive_group)
	if holder != null and is_instance_valid(holder) and holder != boss and holder.is_inside_tree():
		return false
	_diving[exclusive_group] = boss
	return true

func _release() -> void:
	if exclusive_group != &"" and _diving.get(exclusive_group) == boss:
		_diving.erase(exclusive_group)

func _exit_tree() -> void:
	_release()
