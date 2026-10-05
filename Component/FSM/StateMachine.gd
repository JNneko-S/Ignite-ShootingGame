extends Node
class_name StateMachine

@export var initial_state : State ##最初のステートを設定する

var current_state : State
var states : Dictionary

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.StateTransitioned.connect(on_child_transition)
	if initial_state:
		initial_state.Enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.Update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.Physics_Update(delta)

func on_child_transition(state : State, new_state_name) -> void:
	if state != current_state:
		return
	var new_state : State = states.get(new_state_name.to_lower())
	if new_state == null:
		return
	if current_state:
		current_state.Exit()
	new_state.Enter()
	current_state = new_state
