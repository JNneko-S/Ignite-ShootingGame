extends Node
class_name HiddenBoss
## 隠しボスの目印。隠しボス(Enemy)の子に置く。
##   ・出てきたら、実績「目覚める災厄」
##   ・HARD と ANOTHER でしか出ない(それ以外の難易度では、すぐ消える)
##   ・倒されたら、実績「子の親殺し」。RunConfig.hidden_boss_defeated がオンになり、二周目をクリアしたときの合図が congratulation! になる

func _ready() -> void:
	var enemy := get_parent() as Enemy
	if enemy == null:
		push_warning("HiddenBoss: 親が Enemy ではありません")
		return
	# 隠しボスは HARD と ANOTHER でしか出ない(出すときは、SpawnEvent の Hard And Above Only もオンにしておく)
	if DifficultyTuning.chosen() < 2:
		enemy.queue_free()
		return
	Achievements.on_hidden_boss_appeared()
	enemy.died.connect(func(_e : Enemy) -> void: Achievements.on_hidden_boss_defeated())
