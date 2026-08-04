extends Control

const HANGAR_SCENE_PATH := "res://scenes/hangar_screen.tscn"
const STORY_TEST_SCENE_PATH := "res://scenes/story_map_test.tscn"
const TITLE_ART := preload("res://Sprites/Title/Subject-12-Hangar-Gemini-0001.png")
const BG := Color("071014")
const PANEL := Color("0d1b20")
const LINE := Color("24424a")
const TEXT := Color("d7e1df")
const MUTED := Color("718b8e")
const CYAN := Color("5ce1d0")
const RED := Color("e05a55")

var status_label: Label
var delete_panel: PanelContainer


func _ready() -> void:
	_build_interface()
	SceneTransition.transition_failed.connect(_on_transition_failed)
	queue_redraw()
	if OS.get_cmdline_user_args().has("--main-menu-smoke"):
		call_deferred("_run_main_menu_smoke")
	if OS.get_cmdline_user_args().has("--endless-entry-smoke"):
		call_deferred("_on_endless_pressed")
	if OS.get_cmdline_user_args().has("--hangar-main-menu-smoke"):
		print("HANGAR_MAIN_MENU_CHECK passed")
		get_tree().quit(0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)


func _build_interface() -> void:
	var art := TextureRect.new()
	art.texture = TITLE_ART
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)
	move_child(art, 0)

	var menu_panel := Panel.new()
	menu_panel.position = Vector2(313.0, 23.0)
	menu_panel.size = Vector2(158.0, 224.0)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(PANEL, 0.96)
	panel_style.border_color = LINE
	panel_style.set_border_width_all(1)
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(menu_panel)

	var title := _label("SUBJECT", Vector2(320.0, 32.0), Vector2(144.0, 23.0), 19, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_number := _label("//12", Vector2(320.0, 53.0), Vector2(144.0, 25.0), 21, TEXT)
	title_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var specimen := _label("TEST SUBJECT 12 // ONLINE", Vector2(320.0, 78.0), Vector2(144.0, 9.0), 6, RED)
	specimen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.position = Vector2(326.0, 91.0)
	rule.size = Vector2(132.0, 1.0)
	rule.color = MUTED
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	var entries := [
		["STORY MODE", _on_story_pressed],
		["SKIRMISH MODE", _on_skirmish_pressed],
		["ENDLESS MODE", _on_endless_pressed],
		["DELETE SAVE", _on_delete_pressed],
	]
	for index in entries.size():
		var button := Button.new()
		button.position = Vector2(325.0, 101.0 + index * 29.0)
		button.size = Vector2(134.0, 22.0)
		button.text = entries[index][0]
		button.add_theme_font_size_override("font_size", 8)
		_style_menu_button(button)
		button.pressed.connect(entries[index][1])
		add_child(button)
	status_label = _label("ALL MODES AVAILABLE", Vector2(320.0, 221.0), Vector2(144.0, 9.0), 6, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0.0, 5.0), Vector2(5.0, 0.0), Vector2(10.0, 5.0), Vector2(5.0, 10.0),
	])
	diamond.position = Vector2(387.0, 233.0)
	diamond.color = MUTED
	add_child(diamond)
	_build_delete_panel()


func _build_delete_panel() -> void:
	delete_panel = PanelContainer.new()
	delete_panel.position = Vector2(313.0, 78.0)
	delete_panel.size = Vector2(158.0, 116.0)
	delete_panel.visible = false
	add_child(delete_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	delete_panel.add_child(stack)
	var title := Label.new()
	title.text = "DELETE LOCAL DATA?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", RED)
	stack.add_child(title)
	for entry in [
		["DELETE STORY PROGRESS", _delete_story],
		["DELETE ENDLESS SCORE", _delete_endless],
		["CANCEL", _close_delete],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.add_theme_font_size_override("font_size", 7)
		button.pressed.connect(entry[1])
		stack.add_child(button)


func _label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _style_menu_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("10191b")
	normal.border_color = Color("182426")
	normal.set_border_width_all(1)
	var hover := normal.duplicate()
	hover.bg_color = Color("1a292c")
	hover.border_color = MUTED
	var pressed := normal.duplicate()
	pressed.bg_color = Color("24383b")
	pressed.border_color = CYAN
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", CYAN)


func _on_story_pressed() -> void:
	GameSession.selected_game_mode = GameSession.GameMode.STORY
	var error := SceneTransition.transition_to(STORY_TEST_SCENE_PATH)
	if error != OK:
		status_label.text = "TRANSFER FAILED // %s" % error_string(error)


func _on_skirmish_pressed() -> void:
	_enter_hangar(GameSession.GameMode.SKIRMISH)


func _on_endless_pressed() -> void:
	_enter_hangar(GameSession.GameMode.ENDLESS)


func _enter_hangar(mode: GameSession.GameMode) -> void:
	GameSession.selected_game_mode = mode
	var error := SceneTransition.transition_to(HANGAR_SCENE_PATH)
	if error != OK:
		status_label.text = "TRANSFER FAILED // %s" % error_string(error)


func _on_transition_failed(_scene_path: String, error: Error) -> void:
	status_label.text = "TRANSFER FAILED // %s" % error_string(error)


func _on_delete_pressed() -> void:
	delete_panel.visible = true


func _delete_story() -> void:
	var deleted := GameSession.delete_story_progress()
	delete_panel.visible = false
	status_label.text = "STORY PROGRESS DELETED" if deleted else "DELETE FAILED"


func _delete_endless() -> void:
	var deleted := GameSession.delete_endless_score()
	delete_panel.visible = false
	status_label.text = "ENDLESS SCORE DELETED" if deleted else "DELETE FAILED"


func _close_delete() -> void:
	delete_panel.visible = false


func _run_main_menu_smoke() -> void:
	_on_delete_pressed()
	assert(delete_panel.visible)
	_close_delete()
	assert(not delete_panel.visible)
	var original_path: String = GameSession.endless_progress_path
	GameSession.endless_progress_path = "user://main_menu_smoke_endless.json"
	GameSession.delete_endless_score()
	assert(GameSession.submit_endless_score(123) == 123)
	assert(GameSession.load_endless_high_score() == 123)
	assert(GameSession.delete_endless_score())
	assert(GameSession.load_endless_high_score() == 0)
	GameSession.endless_progress_path = original_path
	print("MAIN_MENU_CHECK passed")
	get_tree().quit(0)
