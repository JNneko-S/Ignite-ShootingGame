extends Node
class_name State

signal StateTransitioned(state : State, new_state_name : String)

func Enter() -> void:
	pass

func Exit() -> void:
	pass

func Update(delta) -> void:
	pass

func Physics_Update(delta) -> void:
	pass
