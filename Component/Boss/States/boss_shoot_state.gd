extends BossState
class_name BossShootState
## 決まった砲口に、今の段階の弾幕(EnemyShooter の Phases)を Duration 秒撃たせるステート。
## 砲口を空にすると、撃たずに待つだけのステートになる(登場の間など)。

## 撃たせる砲口
@export var shooters : Array[EnemyShooter] = []
## このステートの長さ(秒)
@export var duration : float = 8.0

func _run(token : int) -> void:
	if not shooters.is_empty():
		await wait_bullets_clear(token) # 第一・第二形態は、前の弾が消えてから撃つ
	if not running(token):
		return
	for shooter in shooters:
		if not is_instance_valid(shooter) or not shooter.enabled:
			continue
		if shooter.has_phases():
			shooter.set_phase(phase())
		else:
			shooter.set_patterns(shooter.patterns, shooter.sequence)
	await wait(duration)
	if not running(token):
		return
	stop_shooters(shooters)
	finish(token)
