class_name ScenarioDialogue
extends Control

signal dialogue_started(scenario_id: String)
signal dialogue_finished(scenario_id: String)
signal line_changed(index: int, speaker: String, text: String)

const SCHEMA_VERSION := 1

@onready var speaker_label: Label = $DialoguePanel/Margin/Content/Speaker
@onready var dialogue_label: Label = $DialoguePanel/Margin/Content/Dialogue

var scenario_id := ""
var dialogue: Array[Dictionary] = []
var current_line_index := -1
var active := false


func _ready() -> void:
	visible = false
	set_process_unhandled_key_input(false)


func play_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Scenario dialogue file does not exist: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to read scenario dialogue: %s" % error_string(FileAccess.get_open_error()))
		return false
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK:
		push_error(
			"Invalid scenario dialogue at line %d: %s" % [
				parser.get_error_line(), parser.get_error_message(),
			]
		)
		return false
	if not parser.data is Dictionary:
		push_error("Scenario dialogue root must be an object: %s" % path)
		return false
	return play_document(parser.data, path)


func play_document(document: Dictionary, source := "<memory>") -> bool:
	if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("Unsupported scenario dialogue schema: %s" % source)
		return false
	var id_value = document.get("id")
	var dialogue_value = document.get("dialogue")
	if not id_value is String or String(id_value).strip_edges().is_empty():
		push_error("Scenario dialogue requires a non-empty id: %s" % source)
		return false
	if not dialogue_value is Array or dialogue_value.is_empty():
		push_error("Scenario dialogue requires at least one line: %s" % source)
		return false

	var parsed_dialogue: Array[Dictionary] = []
	for index in dialogue_value.size():
		var entry = dialogue_value[index]
		if not entry is Dictionary:
			push_error("Scenario dialogue line %d must be an object: %s" % [index, source])
			return false
		var speaker_value = entry.get("speaker")
		var text_value = entry.get("text")
		if (
			not speaker_value is String
			or String(speaker_value).strip_edges().is_empty()
			or not text_value is String
			or String(text_value).strip_edges().is_empty()
		):
			push_error(
				"Scenario dialogue line %d requires non-empty speaker and text: %s" % [
					index, source,
				]
			)
			return false
		parsed_dialogue.append({
			"speaker": String(speaker_value).strip_edges(),
			"text": String(text_value).strip_edges(),
		})

	if active:
		_finish()
	scenario_id = String(id_value).strip_edges()
	dialogue = parsed_dialogue
	current_line_index = 0
	active = true
	visible = true
	set_process_unhandled_key_input(true)
	dialogue_started.emit(scenario_id)
	_display_current_line()
	return true


func advance() -> void:
	if not active:
		return
	current_line_index += 1
	if current_line_index >= dialogue.size():
		_finish()
		return
	_display_current_line()


func current_speaker() -> String:
	return speaker_label.text if active else ""


func current_text() -> String:
	return dialogue_label.text if active else ""


func _display_current_line() -> void:
	var entry := dialogue[current_line_index]
	speaker_label.text = String(entry["speaker"]).to_upper()
	dialogue_label.text = String(entry["text"])
	line_changed.emit(current_line_index, speaker_label.text, dialogue_label.text)


func _finish() -> void:
	var finished_id := scenario_id
	active = false
	visible = false
	set_process_unhandled_key_input(false)
	dialogue.clear()
	current_line_index = -1
	dialogue_finished.emit(finished_id)


func _gui_input(event: InputEvent) -> void:
	if (
		active
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		advance()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		advance()
		get_viewport().set_input_as_handled()
