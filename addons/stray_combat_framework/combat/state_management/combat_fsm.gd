extends Node

const DetectedInput = preload("res://addons/stray_combat_framework/input/detected_inputs/detected_input.gd")
const DetectedSequence = preload("res://addons/stray_combat_framework/input/detected_inputs/detected_sequence.gd")
const DetectedVirtualInput = preload("res://addons/stray_combat_framework/input/detected_inputs/detected_virtual_input.gd")

const Situation = preload("situation.gd")
const FighterState = preload("states/fighter_state.gd")

enum FrameState {
	IDLE,
	START_UP,
	ACTIVE,
	ACTIVE_GAP,
	RECOVERY,
}

export(FrameState) var frame_state: int
export var input_buffer_max_size: int = 2
export var input_max_time_in_buffer: float = 0.3
export var anim_player: NodePath

var condition_dict: Dictionary

var _situation_by_name: Dictionary
var _current_situation: Situation
var _input_buffer: Array
var _anim_player: AnimationPlayer
var _current_transition_animation: String


func _ready() -> void:
	_anim_player = get_node(anim_player) as AnimationPlayer
	_anim_player.connect("animation_finished", self, "_on_AnimPlayer_animation_finished")


func _process(delta: float) -> void:
	if _current_situation != null:
		_current_situation.update()

		if not _input_buffer.empty():
			if frame_state == FrameState.RECOVERY or frame_state == FrameState.IDLE:
				var buffered_detected_input: BufferedDetectedInput = _input_buffer.pop_front()
				_current_situation.update(buffered_detected_input.detected_input)

			for buffered_input in _input_buffer:
				if buffered_input.time_in_buffer >= input_max_time_in_buffer:
					_input_buffer.erase(buffered_input)
				buffered_input.time_in_buffer += delta


func set_current_situation(situation_name: String) -> void:
	if not _situation_by_name.has(situation_name):
		push_warning("Failed to set situation. Situation '%s' does not exist." % situation_name)
		return

	_current_situation = _situation_by_name[situation_name]
	_play_animation(_current_situation.get_root().animation)


func add_situation(situation_name: String, situation: Situation) -> void:
	if situation_name.empty():
		push_error("Situation name can not be empty")
		return
	
	if _situation_by_name.has(situation_name):
		push_warning("Situation with name '%s' already exists." % situation_name)
		return


	for sit_name in _situation_by_name:
		if _situation_by_name[sit_name] == situation:
			push_warning("Situation '%s' already exists under name '%s'" % [situation, sit_name])
			return
		
	_situation_by_name[situation_name] = situation
	situation.connect("state_advanced", self, "_on_Situation_state_advanced")
	situation.connect("state_reverted", self, "_on_Situation_state_reverted")


func remove_situation(situation_name: String) -> void:
	if _situation_by_name.has(situation_name):
		var situation: Situation = _situation_by_name[situation_name]
		if situation == _current_situation:
			_current_situation = null
			
		situation.disconnect("state_advanced", self, "_on_Situation_state_advanced")
		situation.disconnect("state_reverted", self, "_on_Situation_state_reverted")
		_situation_by_name.erase(situation_name)


func buffer_input(detected_input: DetectedInput) -> void:
	var buffered_detected_input := BufferedDetectedInput.new()
	buffered_detected_input.detected_input = detected_input
	_input_buffer.append(buffered_detected_input)


func _buffer_input(buffered_input: BufferedDetectedInput) -> void:
	var current_buffer_size: int = _input_buffer.size()
	if current_buffer_size + 1 > input_buffer_max_size:
		_input_buffer[current_buffer_size - 1] = buffered_input
	else:
		_input_buffer.append(buffered_input)


func _play_animation(animation: String, is_backwards: bool = false) -> void:
	if _anim_player == null:
		push_error("Failed to play animation. AnimationPlayer may not be set.")
		return

	if not _anim_player.has_animation(animation):
		push_error("Failed to play animation. AnimationPlayer does not have animation named '%s'" % animation)
		return
	
	if not is_backwards:
		_anim_player.play(animation)
	else:
		_anim_player.play_backwards(animation)


func _on_Situation_state_advanced(new_state: FighterState, transition_animation: String) -> void:
	_current_transition_animation = transition_animation
	if transition_animation.empty():
		_play_animation(new_state.animation)
	else:
		_play_animation(transition_animation)


func _on_Situation_state_reverted(new_state: FighterState, transition_animation: String) -> void:
	_current_transition_animation = transition_animation
	if transition_animation.empty():
		_play_animation(new_state.animation)
	else:
		_play_animation(transition_animation, true)


func _on_AnimPlayer_animation_finished(animation: String) -> void:
	var current_state := _current_situation.get_current_state()
	var situation_root := _current_situation.get_root()

	if animation == _current_transition_animation:
		_play_animation(current_state.animation)
		_current_transition_animation = ""
	elif animation == current_state.animation:
		if current_state.active_condition.empty() or not situation_root.is_condition_true(current_state.active_condition):
			_current_situation.revert_to_active_state()



class BufferedDetectedInput:
	extends Reference

	const DetectedInput = preload("res://addons/stray_combat_framework/input/detected_inputs/detected_input.gd")

	var detected_input: DetectedInput
	var time_in_buffer: float
