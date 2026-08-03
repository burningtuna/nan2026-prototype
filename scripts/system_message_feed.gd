class_name SystemMessageFeed
extends Control

const MAX_MESSAGES := 4
const FADE_SECONDS := 0.6

@export var message_duration := 4.0

@onready var message_list: VBoxContainer = $MessageList

var messages: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func push_message(text_value: String, duration := -1.0) -> void:
	var normalized_text := text_value.strip_edges()
	if normalized_text.is_empty():
		return
	var lifetime := message_duration if duration <= 0.0 else duration
	var label := Label.new()
	label.text = "> %s" % normalized_text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("d7fffa"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_list.add_child(label)
	messages.append({"label": label, "remaining": lifetime, "duration": lifetime})
	while messages.size() > MAX_MESSAGES:
		_remove_message(0)
	set_process(true)


func clear() -> void:
	while not messages.is_empty():
		_remove_message(0)
	set_process(false)


func message_count() -> int:
	return messages.size()


func _process(delta: float) -> void:
	for index in range(messages.size() - 1, -1, -1):
		var message := messages[index]
		message["remaining"] = float(message["remaining"]) - delta
		var label := message["label"] as Label
		if float(message["remaining"]) <= 0.0:
			_remove_message(index)
		elif is_instance_valid(label):
			label.modulate.a = clampf(float(message["remaining"]) / FADE_SECONDS, 0.0, 1.0)
	if messages.is_empty():
		set_process(false)


func _remove_message(index: int) -> void:
	var label := messages[index]["label"] as Label
	messages.remove_at(index)
	if is_instance_valid(label):
		label.queue_free()
