extends Control

const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"
const HANGAR_PATH := "res://scenes/hangar_screen.tscn"
const STAGES := [
	["STAGE 01", "STATIC TARGETS // 1 VS 4", "res://scenes/stage_01.tscn", false],
	["STAGE 02", "TEAM ENGAGEMENT // 2 VS 2", "res://scenes/stage_02.tscn", false],
	["STAGE 03", "BOSS ENGAGEMENT // 2 VS 1", "res://scenes/stage_03.tscn", true],
	["STAGE 04", "FIELD ADVANCE // RESCUE 4 ALLIES", "res://scenes/stage_04.tscn", true],
	["STAGE 05", "SURVIVAL // 20 DRONES + VERTICAL BEAM", "res://scenes/stage_05.tscn", true],
]

const BG := Color("071014")
const PANEL := Color("0d1b20")
const LINE := Color("24424a")
const TEXT := Color("d7e1df")
const MUTED := Color("718b8e")
const CYAN := Color("5ce1d0")

var status_label: Label


func _ready() -> void:
	GameSession.story_deployment_scene_path = ""
	GameSession.story_stage_selected_directly = false
	_build_interface()
	queue_redraw()
	if OS.get_cmdline_user_args().has("--story-select-smoke"):
		assert(get_tree().get_nodes_in_group("story_stage_button").size() == STAGES.size())
		assert(not bool(STAGES[0][3]) and not bool(STAGES[1][3]))
		assert(bool(STAGES[2][3]) and bool(STAGES[3][3]) and bool(STAGES[4][3]))
		print("STORY_STAGE_SELECT_CHECK passed")
		get_tree().quit(0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for index in 14:
		var y := 18.0 + index * 20.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(LINE, 0.12), 1.0)


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)

	var briefing := VBoxContainer.new()
	briefing.custom_minimum_size.x = 150.0
	briefing.add_theme_constant_override("separation", 8)
	columns.add_child(briefing)
	_add_label(briefing, "STORY OPERATIONS", 20, CYAN)
	_add_label(briefing, "SELECT SIMULATION STAGE", 10, MUTED)
	var rule := HSeparator.new()
	rule.modulate = LINE
	briefing.add_child(rule)
	_add_label(briefing, "Prototype missions can be launched independently. Stage 04 rescue results are recorded for Stage 05.", 11, TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	briefing.add_child(spacer)
	var back := Button.new()
	back.text = "< MAIN MENU"
	_style_button(back)
	back.pressed.connect(_transition.bind(MAIN_MENU_PATH))
	briefing.add_child(back)

	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(PANEL, 0.96)
	panel_style.border_color = LINE
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	list_panel.add_theme_stylebox_override("panel", panel_style)
	columns.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_panel.add_child(list_margin)
	var stage_list := VBoxContainer.new()
	stage_list.add_theme_constant_override("separation", 6)
	list_margin.add_child(stage_list)
	for stage in STAGES:
		var button := Button.new()
		button.text = "%s\n%s" % [stage[0], stage[1]]
		button.custom_minimum_size.y = 36.0
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_to_group("story_stage_button")
		_style_button(button)
		button.pressed.connect(_launch_stage.bind(stage))
		stage_list.add_child(button)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", MUTED)
	stage_list.add_child(status_label)


func _add_label(parent: Node, text: String, font_size: int, color: Color, wrap := false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("102329")
	normal.border_color = LINE
	normal.set_border_width_all(1)
	normal.content_margin_left = 10.0
	var hover := normal.duplicate()
	hover.bg_color = Color("18343a")
	hover.border_color = CYAN
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", CYAN)
	button.add_theme_font_size_override("font_size", 10)


func _transition(scene_path: String) -> void:
	var error := SceneTransition.transition_to(scene_path)
	if error != OK:
		status_label.text = "TRANSFER FAILED // %s" % error_string(error)


func _launch_stage(stage: Array) -> void:
	var stage_path := str(stage[2])
	GameSession.selected_game_mode = GameSession.GameMode.STORY
	GameSession.story_deployment_scene_path = stage_path if bool(stage[3]) else ""
	GameSession.story_stage_selected_directly = true
	_transition(HANGAR_PATH if bool(stage[3]) else stage_path)
