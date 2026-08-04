extends CanvasLayer

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const ACTIVE_SCENES := [
	"res://scenes/hangar_screen.tscn",
	"res://scenes/combat_hud_test.tscn",
	"res://scenes/endless_combat.tscn",
	"res://scenes/story_map_test.tscn",
]
const PANEL := Color("0b171c")
const LINE := Color("31535b")
const TEXT := Color("d7e1df")
const MUTED := Color("789397")
const CYAN := Color("5ce1d0")
const RED := Color("e05a55")

var overlay: Control
var main_menu_button: Button
var return_button: Button
var status_label: Label
var was_paused := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()


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
	panel.position = Vector2(-155.0, -112.0)
	panel.size = Vector2(310.0, 224.0)
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
	var subtitle := _label("CONTROL GUIDE", 7, CYAN)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", LINE)
	stack.add_child(rule)

	_add_control_row(stack, "SHIFT", "TOGGLE PLAYER / TARGET CAMERA")
	_add_control_row(stack, "TAB", "CYCLE SENSOR TARGET")
	_add_control_row(stack, "WASD", "MOVE UNIT")
	_add_control_row(stack, "1 / 2 / 3 / 4", "LEFT / RIGHT / BACKPACK / ALL")

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
	return_button = _button("RETURN // ESC", CYAN)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.pressed.connect(_close_menu)
	buttons.add_child(return_button)


func _add_control_row(parent: VBoxContainer, key_text: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key := _label(key_text, 7, CYAN)
	key.custom_minimum_size.x = 78.0
	row.add_child(key)
	var detail := _label(description, 7, TEXT)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)


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
