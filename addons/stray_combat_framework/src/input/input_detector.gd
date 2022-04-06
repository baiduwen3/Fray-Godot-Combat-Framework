extends Node
##
## A node used to detect inputs and input sequences.
##
## @desc:
##		Before use inputs must first be bound through the bind methods provided.
## 		Bound inputs can be used to register combination and conditional inputs.
## 		Sequences must be added by directly accessing the sequence analyzer property.
##

# Imports
const SequenceAnalyzer = preload("sequence_analysis/sequence_analyzer.gd")
const SequenceAnalyzerTree = preload("sequence_analysis/sequence_analyzer_tree.gd")
const SequenceData = preload("sequence_analysis/sequence_data.gd")
const DetectedInput = preload("detected_inputs/detected_input.gd")
const DetectedInputButton = preload("detected_inputs/detected_input_button.gd")
const DetectedInputSequence = preload("detected_inputs/detected_input_sequence.gd")
const InputBind = preload("binds/input_bind.gd")
const ActionInputBind = preload("binds/action_input_bind.gd")
const JoystickInputBind = preload("binds/joystick_input_bind.gd")
const JoystickAxisInputBind = preload("binds/joystick_input_bind.gd")
const KeyboardInputBind = preload("binds/keyboard_input_bind.gd")
const MouseInputBind = preload("binds/mouse_input_bind.gd")
const CombinationInput = preload("bind_dependent_input/combination_input.gd")
const ConditionalInput = preload("bind_dependent_input/conditional_input.gd")

## Emitted when a bound, registered, or sequence input is detected.
signal input_detected(detected_input)

## The sequence analyzer used to detect sequence inputs.
export var sequence_analyzer: Resource = SequenceAnalyzerTree.new()

var _input_bind_by_id: Dictionary # Dictionary<int, InputBind>
var _combination_input_by_id: Dictionary # Dictionary<int, CombinationInput>
var _conditional_input_by_id: Dictionary # Dictionary<int, ConditionalInput>
var _detected_input_button_by_id: Dictionary # Dictionary<int, DetectedInputButton>
var _released_input_button_by_id: Dictionary # Dictionary<int, DetectedInputButton>
var _ignored_input_hash_set: Dictionary # Dictionary<int, bool>
var _conditions: Dictionary # Dictionary<String, bool>


func _ready() -> void:
	sequence_analyzer.connect("match_found", self, "_on_SequenceTree_match_found")


func _process(delta: float) -> void:
	_check_input_binds()
	_check_combined_inputs()
	_check_conditional_inputs()
	_detect_inputs()

## Returns true if an input is being pressed.
func is_input_pressed(id: int) -> bool:
	if _input_bind_by_id.has(id):
		return _input_bind_by_id[id].is_pressed()
	elif _combination_input_by_id.has(id):
		return _combination_input_by_id[id].is_pressed
	elif _conditional_input_by_id.has(id):
		return _input_bind_by_id[_conditional_input_by_id[id].current_input].is_pressed()
	else:
		push_warning("No input with id '%d' bound." % id)
		return false

## Returns true when a user starts pressing the input, meaning it's true only on the frame the user pressed down the input.
func is_input_just_pressed(id: int) -> bool:
	if _input_bind_by_id.has(id):
		return _input_bind_by_id[id].is_just_pressed()
	elif _combination_input_by_id.has(id):
		return _combination_input_by_id[id].is_just_pressed()
	elif _conditional_input_by_id.has(id):
		return _input_bind_by_id[_conditional_input_by_id[id].current_input].is_just_pressed()
	else:
		push_warning("No input with id '%d' bound." % id)
		return false

## Returns true when the user stops pressing the input, meaning it's true only on the frame that the user released the button.
func is_input_just_released(id: int) -> bool:
	if _input_bind_by_id.has(id):
		return _input_bind_by_id[id].is_just_released()
	elif _combination_input_by_id.has(id):
		return _combination_input_by_id[id].is_just_released()
	elif _conditional_input_by_id.has(id):
		return _input_bind_by_id[_conditional_input_by_id[id].current_input].is_just_released()
	else:
		push_warning("No input with id '%d' bound." % id)
		return false

## Binds input to detector under given id.
func bind_input(id: int, input_bind: InputBind) -> void:
	_input_bind_by_id[id] = input_bind

## Binds action input
func bind_action_input(id: int, action: String) -> void:
	var action_input := ActionInputBind.new()
	action_input.action = action
	bind_input(id, action_input)

## Binds joystick button input
func bind_joystick_input(id: int, device: int, button: int) -> void:
	var joystick_input := JoystickInputBind.new()
	joystick_input.device = device
	joystick_input.button = button
	bind_input(id, joystick_input)

## Binds joystick axis input
func bind_joystick_axis(id: int, device: int, axis: int, deadzone: float) -> void:
	var joystick_axis_input := JoystickAxisInputBind.new()
	joystick_axis_input.device = device
	joystick_axis_input.axis = axis
	joystick_axis_input.deadzone = deadzone
	bind_input(id, joystick_axis_input)

## Binds keyboard key input
func bind_keyboard_input(id: int, key: int) -> void:
	var keyboard_input := KeyboardInputBind.new()
	keyboard_input.key = key
	bind_input(id, keyboard_input)

## Binds mouse button input
func bind_mouse_input(id: int, button: int) -> void:
	var mouse_input := MouseInputBind.new()
	mouse_input.button = button
	bind_input(id, mouse_input)

## Registers combination input using input ids as components.
##
## components is an array of input ids that compose the combination - the id assigned to a combination can not be used as a component
##
## If is_ordered is true, the combination will only be detected if the components are pressed in the order given.
## For example, if the components are 'forward' and 'button_a' then the combination is only triggered if 'forward' is pressed and held, then 'button_a' is pressed.
## The order is ignored if the inputs are pressed simeultaneously.
##
## if press_held_components_on_release is true, then when one component of a combination is released the remaining components are treated as if they were just pressed.
## This is useful for constructing the 'motion inputs' featured in many fighting games.
##
## if is_simeultaneous is true, the combination will only be detected if the components are pressed at the same time
func register_combination_input(id: int, components: PoolIntArray, type: int = CombinationInput.PressType.SYNCHRONOUS, press_held_components_on_release: bool = false) -> void:
	if _input_bind_by_id.has(id) or _conditional_input_by_id.has(id):
		push_error("Failed to register combination input. Combination id is already used by bound or registered input")
		return

	if id in components:
		push_error("Failed to register combination input. Combination id can not be included in components")
		return
	
	if components.size() <= 1:
		push_error("Failed to register combination input. Combination must contain 2 or more components.")
		return

	if _conditional_input_by_id.has(id):
		push_error("Failed to register combination input. Combination components can not include conditional input")
		return

	for cid in components:
		if not _input_bind_by_id.has(cid):
			push_error("Failed to register combination input. Combined ids contain unbound input '%d'" % cid)
			return
		
		if _conditional_input_by_id.has(cid):
			push_error("Failed to register combination input. Combination components can not include a conditional input")
			return

	var combination_input := CombinationInput.new()
	combination_input.components = components
	combination_input.type = type
	combination_input.press_held_components_on_release = press_held_components_on_release

	_combination_input_by_id[id] = combination_input

## Registers conditional input using input ids.
##
## The input_by_condition must be a string : int dictionary where the string represents the condition and the int is a valid input id.
## For example, {"is_on_left_side" : InputEnum.FORWARD, "is_on_right_side" : InputEnum.BACKWARD}
func register_conditional_input(id: int, default_input: int, input_by_condition: Dictionary) -> void:
	for cid in input_by_condition.values():
		if not _input_bind_by_id.has(cid) and not _combination_input_by_id.has(cid):
			push_error("Failed to register conditional input. Input dictionary contains unregistered and unbound input '%d'" % cid)
			return
		
		if cid == id:
			push_error("Failed to register conditional input. Conditional input id can not be included in input dictioanry.")
			return
	
	if not _input_bind_by_id.has(default_input) and not _combination_input_by_id.has(default_input):
		push_error("Failed to register conditional input. Default input '%d' is not bound or a registered combination" % default_input)
		return

	if default_input == id:
		push_error("Failed to register conditional input. Conditional input id can not be used as a default input.")
		return

	var conditional_input := ConditionalInput.new()
	conditional_input.default_input = default_input
	conditional_input.input_by_condition = input_by_condition
	_conditional_input_by_id[id] = conditional_input

## Sets condition to given value. Used for checking conditional inputs.
func set_condition(condition: String, value: bool) -> void:
	_conditions[condition] = value

## Returns the value of a condition set with set_condition.
func is_condition_true(condition: String) -> bool:
	if _conditions.has(condition):
		return _conditions[condition]
	return false

## Clears the condition dict
func clear_conditions() -> void:
	_conditions.clear()


func _check_input_binds() -> void:
	var time_stamp := OS.get_ticks_msec()
	for id in _input_bind_by_id:
		var input_bind := _input_bind_by_id[id] as InputBind
		
		if input_bind.is_just_pressed():
			var detected_input := DetectedInputButton.new()
			detected_input.id = id
			detected_input.time_stamp = time_stamp
			detected_input.is_pressed = true
			detected_input.binds.append(input_bind.duplicate())
			_detected_input_button_by_id[id] = detected_input
		elif input_bind.is_just_released():
			var detected_input := DetectedInputButton.new()
			detected_input.id = id
			detected_input.time_stamp = time_stamp
			detected_input.is_pressed = false
			detected_input.binds.append(input_bind.duplicate())
			detected_input.time_held = time_stamp - _detected_input_button_by_id[id].time_stamp
			_released_input_button_by_id[id] = detected_input
			_unignore_input(id)
		
		input_bind.poll()


func _check_combined_inputs() -> void:
	var time_stamp := OS.get_ticks_msec()
	var detected_input_ids := _detected_input_button_by_id.keys()
	for id in _combination_input_by_id:
		var combination_input: CombinationInput = _combination_input_by_id[id]
		if combination_input.has_ids(detected_input_ids):
			if  _detected_input_button_by_id.has(id):
				continue

			match combination_input.press_type:
				CombinationInput.Type.SYNCHRONOUS:
					if not _is_inputed_quick_enough(combination_input.components):
						continue
				CombinationInput.Type.ORDERED:
					if not _is_inputed_in_order(combination_input.components):
						continue
				var unkown_press_type:
					push_warning("Unkown combination input type '%d' for input with id '%d'" % [unkown_press_type, id])

			combination_input.is_pressed = true

			var detected_input := DetectedInputButton.new()
			detected_input.id = id
			detected_input.time_stamp = time_stamp
			detected_input.is_pressed = true
			_detected_input_button_by_id[id] = detected_input

			for cid in combination_input.components:
				detected_input.binds.append(_input_bind_by_id[cid].duplicate())
				_ignore_input(cid)

		elif _detected_input_button_by_id.has(id):
			if combination_input.press_held_components_on_release:
				for cid in combination_input.components:
					if is_input_pressed(cid):
						_detected_input_button_by_id[cid].time_stamp = time_stamp
						_unignore_input(cid)
			
			combination_input.is_pressed = false

			var detected_input := DetectedInputButton.new()
			detected_input.id = id
			detected_input.time_stamp = time_stamp
			detected_input.is_pressed = false
			detected_input.time_held = time_stamp - _detected_input_button_by_id[id].time_stamp

			for cid in combination_input.components:
				detected_input.binds.append(_input_bind_by_id[cid].duplicate())

			_released_input_button_by_id[id] = detected_input
			_unignore_input(id)
		
		combination_input.poll()


func _check_conditional_inputs() -> void:
	var time_stamp := OS.get_ticks_msec()
	for id in _conditional_input_by_id:
		var conditional_input := _conditional_input_by_id[id] as ConditionalInput
		
		if is_input_just_pressed(conditional_input.current_input):
			var detected_input := DetectedInputButton.new()
			detected_input.id = id
			detected_input.time_stamp = time_stamp
			detected_input.is_pressed = true
			_detected_input_button_by_id[id] = detected_input
		elif is_input_just_released(conditional_input.current_input):
			var detected_input := DetectedInputButton.new()
			detected_input.id = id
			detected_input.time_stamp = time_stamp
			detected_input.is_pressed = false
			detected_input.time_held = time_stamp - _detected_input_button_by_id[id].time_stamp
			_released_input_button_by_id[id] = detected_input
			#_detected_input_button_by_id.erase(id)
			_unignore_input(id)

		# Update current condition
		conditional_input.current_input = conditional_input.default_input
		for condition in conditional_input.input_by_condition:
			if is_condition_true(condition):
				conditional_input.current_input = conditional_input.input_by_condition[condition]
				break


func _detect_inputs() -> void:
	for id in _released_input_button_by_id:
		var detected_input: DetectedInput = _released_input_button_by_id[id]
		sequence_analyzer.read(detected_input)
		emit_signal("input_detected", detected_input)
		_detected_input_button_by_id.erase(id)

	for id in _detected_input_button_by_id:
		var detected_input: DetectedInput = _detected_input_button_by_id[id]
		if not _ignored_input_hash_set.has(id):
			sequence_analyzer.read(detected_input)
			emit_signal("input_detected", detected_input)
			_ignore_input(id)

	_released_input_button_by_id.clear()


func _ignore_input(input_id: int) -> void:
	_ignored_input_hash_set[input_id] = true


func _unignore_input(input_id: int) -> void:
	if _ignored_input_hash_set.has(input_id):
		_ignored_input_hash_set.erase(input_id)


func _is_inputed_quick_enough(components: PoolIntArray, tolerance: float = 30) -> bool:
	var avg_difference := 0
	for i in len(components):
		if i > 0:
			avg_difference += _detected_input_button_by_id[components[i]].get_time_between(_detected_input_button_by_id[components[i - 1]])

	avg_difference /= float(components.size())
	if avg_difference <= tolerance:
		return true
	
	return false


func _is_inputed_in_order(components: PoolIntArray, tolerance: float = 30) -> bool:
	if components.size() <= 1:
		return false

	for i in range(1, components.size()):
		var input1: DetectedInput = _detected_input_button_by_id[components[i - 1]]
		var input2: DetectedInput = _detected_input_button_by_id[components[i]]

		if input1.time_stamp - tolerance > input2.time_stamp:
			return false

	return true


func _on_SequenceTree_match_found(sequence_name: String, sequence: PoolIntArray) -> void:
	var detected_input := DetectedInputSequence.new()
	detected_input.name = sequence_name
	detected_input.sequence = sequence
	emit_signal("input_detected", detected_input)
