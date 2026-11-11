extends State
class_name BossState
## ボスの攻撃のステートの土台。StateMachine(ボスの子)の子に置く。
## 1つのステートが終わると Next State の名前のステートへ移る。並べ方の例(BlackSwan):
##   Intro → Barrage → CrossFire → Barrage2 → Dive → Barrage → …
## 段階(第一形態・第二形態…)は、ボスの BossPhaseController の今の段階を見る。
## ステートで撃たせる砲口は、EnemyShooter の Autostart をオフにしておく。
## ステートに砲口を任せるときは、BossPhaseController の Switch Shooters もオフにする。

## このステートが終わったら移るステートの名前(StateMachine の子の名前。大文字小文字は区別しない)
@export var next_state : String = ""
## true なら、入ったときに、このボスの全ての砲口を止める(ほかの弾幕と一緒に撃たない)
@export var stop_all_shooters : bool = true

var boss : Enemy
## Exit で増える。動いている処理は、これが変わったら止まる
var _token : int = 0

func _ready() -> void:
	var node := get_parent()
	while node and not node is Enemy:
		node = node.get_parent()
	boss = node as Enemy

func Enter() -> void:
	_token += 1
	if stop_all_shooters:
		stop_shooters(all_shooters())
	_run.call_deferred(_token)

func Exit() -> void:
	_token += 1

## ステートの中身。終わったら finish(token) を呼ぶ
func _run(_token_at_start : int) -> void:
	pass

## ステートが終わった: 次のステートへ
func finish(token : int) -> void:
	if token == _token and alive():
		StateTransitioned.emit(self, next_state)

## まだこのステートを続けてよいか(ボスが生きていて、ほかのステートに移っていない)
func running(token : int) -> bool:
	return token == _token and alive()

func alive() -> bool:
	return is_instance_valid(boss) and boss.is_inside_tree() and not boss._is_dead

## 今の段階(0 = 第一形態)。BossPhaseController がなければ 0
func phase() -> int:
	if boss == null:
		return 0
	for child in boss.get_children():
		if child is BossPhaseController:
			return child.current_phase()
	return 0

func all_shooters() -> Array[EnemyShooter]:
	var result : Array[EnemyShooter] = []
	if boss:
		for node in boss.find_children("*", "", true, false):
			if node is EnemyShooter:
				result.append(node)
	return result

func stop_shooters(shooters : Array[EnemyShooter]) -> void:
	for shooter in shooters:
		if is_instance_valid(shooter):
			shooter.stop()
			shooter.turn_degrees = 0.0

func wait(seconds : float) -> void:
	if seconds > 0.0 and is_inside_tree():
		await get_tree().create_timer(seconds, false).timeout
