extends Node
class_name PhaseBreak
## ボスの段階が At Phase(0 が最初)になったら、Parts の部位を壊す(撃たなくても壊れる)。ボス(Enemy)の子に置く。
## 例: ラスボスが第二形態になると、エンジンを覆う水晶が砕けて、壊れたエンジンがむき出しになる

@export var parts : Array[EnemyPart] = []
@export var at_phase : int = 1

func _ready() -> void:
	var controller := get_parent().get_node_or_null("BossPhaseController")
	if controller and controller.has_signal("phase_started"):
		controller.phase_started.connect(_on_phase_started)

func _on_phase_started(index : int) -> void:
	if index < at_phase:
		return
	for part in parts:
		if is_instance_valid(part) and not part.is_destroyed():
			part._destroy()
