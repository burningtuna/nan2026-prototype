extends CanvasLayer

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const CONTROL_GUIDE_PATH := "res://data/pause/control_guide.json"
const HANGAR_STATS_PATH := "res://data/pause/hangar_stats.json"
const SCENARIO_OBJECTIVES_PATH := "res://data/pause/scenario_objectives.json"
const HANGAR_SCENE_PATH := "res://scenes/hangar_screen.tscn"
const ACTIVE_SCENES := [
	"res://scenes/hangar_screen.tscn",
	"res://scenes/combat_hud_test.tscn",
	"res://scenes/endless_combat.tscn",
	"res://scenes/story_map_test.tscn",
	"res://scenes/story_stage_select.tscn",
	"res://scenes/stage_01.tscn",
	"res://scenes/stage_02.tscn",
	"res://scenes/stage_03.tscn",
	"res://scenes/stage_04.tscn",
	"res://scenes/stage_05.tscn",
]
const PANEL := Color("0b171c")
const LINE := Color("31535b")
const TEXT := Color("d7e1df")
const MUTED := Color("789397")
const CYAN := Color("5ce1d0")
const RED := Color("e05a55")

var overlay: Control
var main_menu_button: Button
var stage_action_button: Button
var return_button: Button
var status_label: Label
var subtitle_label: Label
var content_stack: VBoxContainer
var was_paused := false
var control_guide := {}
var hangar_stats := {}
var scenario_objectives := {}
var current_content_kind := ""
var rendered_texts: Array[String] = []


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	control_guide = _load_document(CONTROL_GUIDE_PATH)
	hangar_stats = _load_document(HANGAR_STATS_PATH)
	scenario_objectives = _load_document(SCENARIO_OBJECTIVES_PATH)
	_build_interface()
	if OS.get_cmdline_user_args().has("--pause-menu-smoke"):
		call_deferred("_run_pause_menu_smoke")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if overlay.visible:
		_close_menu()
	elif _is_available_in_current_scene() and not SceneTransition.transitioning:
		_open_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_interface() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.03, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210.0, -122.0)
	panel.size = Vector2(420.0, 244.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	var title := _label("SYSTEM // PAUSED", 13, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	subtitle_label = _label("SYSTEM INFORMATION", 7, CYAN)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle_label)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", LINE)
	stack.add_child(rule)

	content_stack = VBoxContainer.new()
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_theme_constant_override("separation", 2)
	stack.add_child(content_stack)

	status_label = _label("ESC CLOSES THIS MENU", 6, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	stack.add_child(buttons)
	main_menu_button = _button("MAIN MENU", RED)
	main_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_menu_button.pressed.connect(_return_to_main_menu)
	buttons.add_child(main_menu_button)
	stage_action_button = _button("RESTART STAGE", CYAN)
	stage_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_action_button.pressed.connect(_activate_stage_action)
	buttons.add_child(stage_action_button)
	return_button = _button("RETURN // ESC", CYAN)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.pressed.connect(_close_menu)
	buttons.add_child(return_button)


func _add_control_row(parent: VBoxContainer, key_text: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key := _label(key_text, 7, CYAN)
	key.custom_minimum_size.x = 92.0
	row.add_child(key)
	var detail := _label(description, 7, TEXT)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)


func _add_section_title(value: String) -> void:
	rendered_texts.append(value)
	var label := _label(value, 7, CYAN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content_stack.add_child(label)


func _add_wrapped_text(value: String, color := TEXT) -> void:
	rendered_texts.append(value)
	var label := _label(value, 7, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_stack.add_child(label)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, accent: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 23.0
	button.text = value
	button.add_theme_font_size_override("font_size", 7)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_stylebox_override("normal", _button_style(Color("101f24"), LINE))
	button.add_theme_stylebox_override("hover", _button_style(Color("17343a"), accent))
	button.add_theme_stylebox_override("pressed", _button_style(Color("091419"), accent))
	button.add_theme_stylebox_override("focus", _button_style(Color("132a30"), accent))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL, 0.94)
	style.border_color = LINE
	style.set_border_width_all(1)
	return style


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	return style


func _is_available_in_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path in ACTIVE_SCENES


func _open_menu() -> void:
	was_paused = get_tree().paused
	status_label.text = "ESC CLOSES THIS MENU"
	main_menu_button.disabled = false
	stage_action_button.disabled = false
	return_button.disabled = false
	_configure_stage_action()
	_populate_content()
	overlay.visible = true
	get_tree().paused = true
	return_button.grab_focus()


func _close_menu() -> void:
	overlay.visible = false
	get_tree().paused = was_paused


func _return_to_main_menu() -> void:
	main_menu_button.disabled = true
	status_label.text = "TRANSFER // MAIN MENU"
	_close_menu()
	var error := SceneTransition.transition_to(MAIN_MENU_SCENE_PATH)
	if error == OK:
		return
	_open_menu()
	status_label.text = "TRANSFER FAILED // %s" % error_string(error)


func _configure_stage_action() -> void:
	var scene_path := _current_scene_path()
	stage_action_button.visible = GameSession.is_story_stage_path(scene_path)
	if not stage_action_button.visible:
		return
	stage_action_button.text = (
		"RETURN TO HANGAR"
		if GameSession.story_stage_starts_from_hangar(scene_path)
		else "RESTART STAGE"
	)


func _activate_stage_action() -> void:
	var scene_path := _current_scene_path()
	if not GameSession.is_story_stage_path(scene_path):
		return
	var returns_to_hangar := GameSession.story_stage_starts_from_hangar(scene_path)
	var destination := HANGAR_SCENE_PATH if returns_to_hangar else scene_path
	if returns_to_hangar:
		_prepare_story_hangar_return(scene_path)
	main_menu_button.disabled = true
	stage_action_button.disabled = true
	return_button.disabled = true
	status_label.text = "TRANSFER // %s" % ("HANGAR" if returns_to_hangar else "RESTART")
	_close_menu()
	var error := SceneTransition.transition_to(destination)
	if error == OK:
		return
	_open_menu()
	return_button.disabled = false
	status_label.text = "TRANSFER FAILED // %s" % error_string(error)


func _prepare_story_hangar_return(scene_path: String) -> void:
	GameSession.selected_game_mode = GameSession.GameMode.STORY
	GameSession.story_deployment_scene_path = scene_path


func _current_scene_path() -> String:
	var current_scene := get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""


func _populate_content() -> void:
	rendered_texts.clear()
	for child in content_stack.get_children():
		content_stack.remove_child(child)
		child.queue_free()
	var current_scene := get_tree().current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	if scene_path == HANGAR_SCENE_PATH:
		current_content_kind = "hangar_stats"
		subtitle_label.text = str(hangar_stats.get("title", "ASSEMBLY STAT GUIDE"))
		_add_entries(hangar_stats.get("entries", []))
		return
	var scenes: Dictionary = scenario_objectives.get("scenes", {})
	var scenario: Dictionary = scenes.get(scene_path, {})
	if not scenario.is_empty():
		current_content_kind = "scenario"
		subtitle_label.text = "CURRENT OBJECTIVE"
		_add_scenario_content(scenario, current_scene)
		if bool(scenario.get("show_controls", true)):
			_add_separator()
			_add_section_title(str(control_guide.get("title", "CONTROL GUIDE")))
			_add_entries(control_guide.get("entries", []))
		return
	current_content_kind = "controls"
	subtitle_label.text = str(control_guide.get("title", "CONTROL GUIDE"))
	_add_entries(control_guide.get("entries", []))


func _add_scenario_content(scenario: Dictionary, current_scene: Node) -> void:
	var context := {}
	if current_scene != null and current_scene.has_method("pause_menu_context"):
		context = current_scene.pause_menu_context()
	var content := scenario
	var phases: Dictionary = scenario.get("phases", {})
	var phase := str(context.get("phase", ""))
	if phases.has(phase):
		content = scenario.duplicate(true)
		content.merge(phases[phase], true)
	_add_section_title(str(content.get("title", scenario.get("title", "MISSION"))))
	_add_wrapped_text(_format_text(str(content.get("objective", "NO OBJECTIVE DATA")), context))
	var progress := _format_text(str(content.get("progress", "")), context)
	if not progress.is_empty():
		_add_wrapped_text(progress, MUTED)


func _add_entries(entries) -> void:
	if not entries is Array:
		return
	for entry in entries:
		if entry is Dictionary:
			rendered_texts.append("%s // %s" % [entry.get("key", ""), entry.get("description", "")])
			_add_control_row(
				content_stack,
				str(entry.get("key", "")),
				str(entry.get("description", ""))
			)


func _add_separator() -> void:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", LINE)
	content_stack.add_child(separator)


func _format_text(value: String, context: Dictionary) -> String:
	return value.format(context)


func _load_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Pause menu data is missing: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open pause menu data: %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_error("Invalid pause menu JSON: %s" % path)
		return {}
	return parser.data


func _run_pause_menu_smoke() -> void:
	await get_tree().process_frame
	assert(_is_available_in_current_scene())
	_open_menu()
	assert(overlay.visible and get_tree().paused)
	assert(not current_content_kind.is_empty())
	assert(content_stack.get_child_count() > 0)
	var scene_path := get_tree().current_scene.scene_file_path
	assert(stage_action_button.visible == GameSession.is_story_stage_path(scene_path))
	if GameSession.is_story_stage_path(scene_path):
		assert(stage_action_button.text == (
			"RETURN TO HANGAR"
			if GameSession.story_stage_starts_from_hangar(scene_path)
			else "RESTART STAGE"
		))
		if GameSession.story_stage_starts_from_hangar(scene_path):
			var selected_directly_before := GameSession.story_stage_selected_directly
			GameSession.story_deployment_scene_path = "res://scenes/stage_01.tscn"
			_prepare_story_hangar_return(scene_path)
			assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
			assert(GameSession.story_deployment_scene_path == scene_path)
			assert(GameSession.story_stage_selected_directly == selected_directly_before)
	for story_stage_path in GameSession.STORY_STAGE_PATHS:
		assert(GameSession.story_stage_starts_from_hangar(story_stage_path) == (
			story_stage_path != "res://scenes/stage_01.tscn"
		))
	if scene_path == HANGAR_SCENE_PATH:
		assert(current_content_kind == "hangar_stats")
		assert(rendered_texts.any(func(value: String) -> bool: return value.begins_with("ARMOR //")))
	else:
		var scenes: Dictionary = scenario_objectives.get("scenes", {})
		if scenes.has(scene_path):
			assert(current_content_kind == "scenario")
			for value in rendered_texts:
				assert(not value.contains("{"))
	_close_menu()
	assert(not overlay.visible and not get_tree().paused)
	print("PAUSE_MENU_CHECK passed // %s" % get_tree().current_scene.scene_file_path)
	get_tree().quit(0)
