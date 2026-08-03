extends Control

const HANGAR_SCENE_PATH := "res://scenes/hangar_screen.tscn"
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
	for y in range(0, int(size.y), 6):
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.12, 0.25, 0.27, 0.08))
	draw_rect(Rect2(138.0, 35.0, 204.0, 202.0), PANEL)
	draw_rect(Rect2(138.0, 35.0, 204.0, 202.0), LINE, false, 1.0)


func _build_interface() -> void:
	var title := _label("DIRECTIVE//12", Vector2(150.0, 48.0), Vector2(180.0, 24.0), 18, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label("SELECT OPERATION MODE", Vector2(150.0, 73.0), Vector2(180.0, 12.0), 7, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var entries := [
		["STORY MODE", _on_story_pressed],
		["SKIRMISH MODE", _on_skirmish_pressed],
		["ENDLESS MODE", _on_endless_pressed],
		["DELETE SAVE", _on_delete_pressed],
	]
	for index in entries.size():
		var button := Button.new()
		button.position = Vector2(168.0, 96.0 + index * 30.0)
		button.size = Vector2(144.0, 22.0)
		button.text = entries[index][0]
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(entries[index][1])
		add_child(button)
	status_label = _label("ALL MODES AVAILABLE", Vector2(150.0, 218.0), Vector2(180.0, 10.0), 6, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_delete_panel()


func _build_delete_panel() -> void:
	delete_panel = PanelContainer.new()
	delete_panel.position = Vector2(145.0, 78.0)
	delete_panel.size = Vector2(190.0, 116.0)
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


func _on_story_pressed() -> void:
	status_label.text = "STORY MODE // IN DEVELOPMENT"


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
	_on_story_pressed()
	assert(status_label.text == "STORY MODE // IN DEVELOPMENT")
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
