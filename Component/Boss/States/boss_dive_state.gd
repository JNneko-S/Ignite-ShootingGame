extends BossState
class_name BossDiveState
## AfterburnerDive の技(一番下まで突っ込んで、炎を噴いて上がる)を1回するステート。
## AfterburnerDive の Auto Run はオフにしておく(このステートが始める)。
## From Phase より前の段階では、何もせずに次のステートへ移る。

@export var dive : AfterburnerDive
## この段階(0 = 第一形態)から使う
@export var from_phase : int = 0

func _run(token : int) -> void:
	if not running(token):
		return
	if is_instance_valid(dive) and phase() >= from_phase:
		await dive.perform()
	finish(token)
