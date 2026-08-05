extends Control

const BG := Color("071014")
const PANEL := Color("0d1b20")
const PANEL_ALT := Color("11252a")
const LINE := Color("24424a")
const TEXT := Color("d7e1df")
const MUTED := Color("718b8e")
const CYAN := Color("5ce1d0")
const AMBER := Color("f5bd55")
const RED := Color("e05a55")
const PARTS_DATA_PATH := "res://data/mech_parts.json"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SKIRMISH_SCENE_PATH := "res://scenes/combat_hud_test.tscn"
const ENDLESS_SCENE_PATH := "res://scenes/endless_combat.tscn"
const STORY_STAGE_SELECT_PATH := "res://scenes/story_stage_select.tscn"
const ENDLESS_INTRO_PATH := "res://data/scenarios/endless_intro.json"
const SCENARIO_DIALOGUE_SCENE := preload("res://scenes/scenario_dialogue.tscn")

const SLOT_NAMES := {
	MechLoadout.MechSlot.BODY: "BODY",
	MechLoadout.MechSlot.HEAD: "HEAD",
	MechLoadout.MechSlot.LEFT_ARM: "LEFT ARM",
	MechLoadout.MechSlot.RIGHT_ARM: "RIGHT ARM",
	MechLoadout.MechSlot.BACKPACK: "BACKPACK",
	MechLoadout.MechSlot.LEGS: "LEGS",
}
const SLOT_ORDER := [
	MechLoadout.MechSlot.BODY,
	MechLoadout.MechSlot.HEAD,
	MechLoadout.MechSlot.LEFT_ARM,
	MechLoadout.MechSlot.RIGHT_ARM,
	MechLoadout.MechSlot.BACKPACK,
	MechLoadout.MechSlot.LEGS,
]

@onready var mech_preview: MechWireframePreview = $MechPreview

var _catalog: Dictionary = {}
var _part_catalog: MechPartCatalog
var _working_loadout: MechLoadout
var _slot_buttons: Dictionary = {}
var _stat_bars: Dictionary = {}
var _status_label: Label
var _validation_label: Label
var _confirm_button: Button
var _main_menu_button: Button
var _overlay: Control
var _overlay_title: Label
var _candidate_list: VBoxContainer
var _candidate_parts: Dictionary = {}
var _detail_name: Label
var _detail_kind: Label
var _detail_description: Label
var _detail_stats: Label
var _detail_weapon: Label
var _equip_button: Button
var _pending_part: MechPartSpec
var _active_slot := MechLoadout.MechSlot.BODY
var _confirmed := false
var _scenario_dialogue: ScenarioDialogue


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--story-hangar-smoke") or OS.get_cmdline_user_args().has("--story-deploy-smoke"):
		GameSession.selected_game_mode = GameSession.GameMode.STORY
		GameSession.story_deployment_scene_path = "res://scenes/stage_03.tscn"
	if not _build_catalog():
		return
	_working_loadout = _initial_loadout()
	_build_interface()
	_refresh()
	_scenario_dialogue = SCENARIO_DIALOGUE_SCENE.instantiate() as ScenarioDialogue
	add_child(_scenario_dialogue)
	if (
		GameSession.selected_game_mode == GameSession.GameMode.ENDLESS
		and not GameSession.endless_intro_shown
		and _scenario_dialogue.play_file(ENDLESS_INTRO_PATH)
	):
		GameSession.endless_intro_shown = true
	queue_redraw()
	if OS.get_cmdline_user_args().has("--scene-transition-smoke"):
		call_deferred("_confirm_loadout")
	if OS.get_cmdline_user_args().has("--endless-entry-smoke"):
		if SceneTransition.transitioning:
			SceneTransition.transition_finished.connect(
				func(_scene_path: String) -> void: _run_endless_hangar_entry_smoke(),
				CONNECT_ONE_SHOT
			)
		else:
			call_deferred("_run_endless_hangar_entry_smoke")
	if OS.get_cmdline_user_args().has("--hangar-main-menu-smoke"):
		call_deferred("_return_to_main_menu")
	if OS.get_cmdline_user_args().has("--hangar-return-smoke"):
		print("HANGAR_RETURN_CHECK passed")
		get_tree().quit(0)
	if OS.get_cmdline_user_args().has("--story-hangar-smoke"):
		call_deferred("_run_story_hangar_smoke")
	if OS.get_cmdline_user_args().has("--story-deploy-smoke"):
		call_deferred("_confirm_loadout")


func _run_endless_hangar_entry_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.ENDLESS)
	assert(_scenario_dialogue.active)
	assert(_scenario_dialogue.current_text() == "무한 모드입니다. 뱀파이어 서바이버 처럼 최대한 오래 살아남는게 목적입니다.")
	_scenario_dialogue.advance()
	assert(_scenario_dialogue.current_text() == "다른 모드와 별개의 장비 스탯을 사용합니다. 재장전 스트레스 없이 열, EN 관리가 목표가 됩니다.")
	_scenario_dialogue.advance()
	assert(not _scenario_dialogue.active)
	_confirm_loadout()


func _run_story_hangar_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
	assert(_deployment_scene_path() == "res://scenes/stage_03.tscn")
	assert(_confirm_button.text == "DEPLOY STORY")
	print("STORY_HANGAR_CHECK passed")
	get_tree().quit(0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for y in range(0, int(size.y), 6):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.25, 0.27, 0.08), 1.0)
	_draw_panel(Rect2(8, 38, 168, 148))
	_draw_panel(Rect2(184, 38, 288, 148))
	_draw_panel(Rect2(8, 194, 464, 68))
	draw_line(Vector2(184, 31), Vector2(472, 31), LINE, 1.0)
	draw_arc(Vector2(336, 107), 59.0, 0.0, TAU, 64, Color(0.18, 0.48, 0.48, 0.28), 1.0)
	draw_arc(Vector2(336, 107), 48.0, -2.5, 0.7, 32, Color(0.36, 0.88, 0.82, 0.35), 1.0)
	draw_line(Vector2(273, 107), Vector2(399, 107), Color(0.3, 0.7, 0.68, 0.14), 1.0)
	draw_line(Vector2(336, 47), Vector2(336, 167), Color(0.3, 0.7, 0.68, 0.14), 1.0)


func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, LINE, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(13, 0), CYAN, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, 13), CYAN, 2.0)


func _build_interface() -> void:
	_make_label(self, "SUBJECT//12", Vector2(9, 5), Vector2(130, 18), 14, CYAN)
	_make_label(self, "HANGAR / LOADOUT ASSEMBLY", Vector2(105, 7), Vector2(220, 16), 9, MUTED)
	_make_label(self, "FRAME 01", Vector2(405, 7), Vector2(67, 16), 9, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_make_label(self, "01  PART CONFIGURATION", Vector2(14, 43), Vector2(156, 14), 8, MUTED)
	_make_label(self, "02  ASSEMBLED FRAME", Vector2(190, 43), Vector2(150, 14), 8, MUTED)
	_make_label(self, "03  SYSTEM OUTPUT", Vector2(14, 199), Vector2(140, 13), 8, MUTED)

	for index in SLOT_ORDER.size():
		var slot: MechLoadout.MechSlot = SLOT_ORDER[index]
		var button := Button.new()
		button.position = Vector2(14, 59 + index * 20)
		button.size = Vector2(156, 18)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 8)
		button.add_theme_stylebox_override("normal", _style(PANEL_ALT, LINE))
		button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
		button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
		button.add_theme_stylebox_override("focus", _style(Color("17343a"), CYAN))
		button.pressed.connect(_open_part_picker.bind(slot))
		add_child(button)
		_slot_buttons[slot] = button

	_status_label = _make_label(self, "EDITING", Vector2(380, 43), Vector2(84, 14), 8, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_make_label(self, "FRONT WIREFRAME PREVIEW", Vector2(255, 169), Vector2(162, 11), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	var stat_defs := [
		["ARMOR", 600.0],
		["FIREPOWER", 160.0],
		["MOBILITY", 100.0],
		["COOLING", 100.0],
		["POWER", 100.0],
		["WEIGHT", 100.0],
	]
	for index in stat_defs.size():
		var column := index % 3
		var row := index / 3
		var origin := Vector2(14 + column * 116, 214 + row * 20)
		var stat_name: String = stat_defs[index][0]
		_make_label(self, stat_name, origin, Vector2(52, 10), 7, MUTED)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.position = origin + Vector2(0, 10)
		bar.size = Vector2(106, 8)
		bar.max_value = stat_defs[index][1]
		bar.add_theme_stylebox_override("background", _style(Color("081216"), Color("1b363d"), 0))
		bar.add_theme_stylebox_override("fill", _style(CYAN, CYAN, 0))
		add_child(bar)
		var value_label := _make_label(self, "0", origin + Vector2(52, -1), Vector2(54, 10), 7, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_stat_bars[stat_name] = {"bar": bar, "label": value_label}

	_validation_label = _make_label(self, "", Vector2(365, 213), Vector2(101, 21), 7, RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_validation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_button = Button.new()
	_confirm_button.position = Vector2(365, 237)
	_confirm_button.size = Vector2(101, 19)
	_confirm_button.text = "CONFIRM LOADOUT"
	if GameSession.selected_game_mode == GameSession.GameMode.ENDLESS:
		_confirm_button.text = "DEPLOY ENDLESS"
	elif GameSession.selected_game_mode == GameSession.GameMode.STORY:
		_confirm_button.text = "DEPLOY STORY"
	_confirm_button.add_theme_font_size_override("font_size", 8)
	_confirm_button.add_theme_color_override("font_color", BG)
	_confirm_button.add_theme_color_override("font_disabled_color", MUTED)
	_confirm_button.add_theme_stylebox_override("normal", _style(CYAN, CYAN))
	_confirm_button.add_theme_stylebox_override("hover", _style(Color("8ff9e9"), Color("8ff9e9")))
	_confirm_button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER))
	_confirm_button.add_theme_stylebox_override("disabled", _style(Color("17282d"), LINE))
	_confirm_button.pressed.connect(_confirm_loadout)
	add_child(_confirm_button)

	_main_menu_button = Button.new()
	_main_menu_button.position = Vector2(365, 194)
	_main_menu_button.size = Vector2(101, 16)
	_main_menu_button.text = "MAIN MENU"
	_main_menu_button.add_theme_font_size_override("font_size", 7)
	_main_menu_button.add_theme_stylebox_override("normal", _style(PANEL_ALT, LINE))
	_main_menu_button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
	_main_menu_button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
	_main_menu_button.pressed.connect(_return_to_main_menu)
	add_child(_main_menu_button)

	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.04, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(24, 25)
	panel.size = Vector2(432, 220)
	panel.add_theme_stylebox_override("panel", _style(PANEL_ALT, CYAN, 2))
	_overlay.add_child(panel)

	_overlay_title = _make_label(panel, "SELECT PART", Vector2(12, 8), Vector2(330, 17), 11, CYAN)
	_make_label(panel, "SELECT COMPONENT / REVIEW / EQUIP", Vector2(12, 26), Vector2(300, 12), 7, MUTED)

	var close := Button.new()
	close.position = Vector2(398, 8)
	close.size = Vector2(24, 18)
	close.text = "X"
	close.add_theme_font_size_override("font_size", 9)
	close.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	close.add_theme_stylebox_override("hover", _style(Color("351a1a"), RED))
	close.pressed.connect(_close_part_picker)
	panel.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 43)
	scroll.size = Vector2(190, 164)
	panel.add_child(scroll)
	_candidate_list = VBoxContainer.new()
	_candidate_list.custom_minimum_size = Vector2(180, 0)
	_candidate_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_candidate_list)

	var divider := ColorRect.new()
	divider.position = Vector2(207, 43)
	divider.size = Vector2(1, 164)
	divider.color = LINE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_detail_name = _make_label(panel, "COMPONENT", Vector2(216, 43), Vector2(202, 17), 10, TEXT)
	_detail_kind = _make_label(panel, "SYSTEM", Vector2(216, 61), Vector2(202, 11), 7, AMBER)
	_detail_description = _make_label(panel, "", Vector2(216, 76), Vector2(202, 43), 7, TEXT)
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_stats = _make_label(panel, "", Vector2(216, 123), Vector2(202, 25), 7, MUTED)
	_detail_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_weapon = _make_label(panel, "", Vector2(216, 150), Vector2(202, 27), 7, CYAN)
	_detail_weapon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_equip_button = Button.new()
	_equip_button.position = Vector2(216, 181)
	_equip_button.size = Vector2(202, 26)
	_equip_button.text = "EQUIP"
	_equip_button.add_theme_font_size_override("font_size", 9)
	_equip_button.add_theme_color_override("font_color", BG)
	_equip_button.add_theme_color_override("font_disabled_color", MUTED)
	_equip_button.add_theme_stylebox_override("normal", _style(CYAN, CYAN))
	_equip_button.add_theme_stylebox_override("hover", _style(Color("8ff9e9"), Color("8ff9e9")))
	_equip_button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER))
	_equip_button.add_theme_stylebox_override("disabled", _style(Color("17282d"), LINE))
	_equip_button.pressed.connect(_equip_pending_part)
	panel.add_child(_equip_button)


func _build_catalog() -> bool:
	_part_catalog = MechPartCatalog.new()
	if not _part_catalog.load_file(PARTS_DATA_PATH):
		push_error("Unable to initialize Hangar part catalog")
		return false
	_catalog = _part_catalog.parts_by_type
	return true


func _initial_loadout() -> MechLoadout:
	var saved_loadout := GameSession.load_saved_player_loadout(_part_catalog)
	if saved_loadout != null:
		return saved_loadout
	return _part_catalog.create_default_loadout()


func _open_part_picker(slot: MechLoadout.MechSlot) -> void:
	_active_slot = slot
	_overlay_title.text = "SELECT // %s" % SLOT_NAMES[slot]
	_candidate_parts.clear()
	for child in _candidate_list.get_children():
		_candidate_list.remove_child(child)
		child.queue_free()

	if _is_optional(slot):
		_add_candidate_button(null)
	var expected_type := _part_type_for_slot(slot)
	for part: MechPartSpec in _catalog.get(expected_type, []):
		_add_candidate_button(part)
	_pending_part = _working_loadout.part_for_slot(_active_slot)
	_update_candidate_details()
	_overlay.visible = true


func _add_candidate_button(part: MechPartSpec) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 20)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 8)
	button.toggle_mode = true
	button.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
	var equipped_part := _working_loadout.part_for_slot(_active_slot)
	var marker := ">" if equipped_part == part else " "
	if part == null:
		button.text = " %s -- EMPTY MOUNT --" % marker
		button.add_theme_color_override("font_color", MUTED)
	else:
		button.text = " %s %s  %s" % [marker, part.designation, part.display_name]
	button.pressed.connect(_preview_candidate.bind(part))
	_candidate_parts[button] = part
	_candidate_list.add_child(button)


func _preview_candidate(part: MechPartSpec) -> void:
	_pending_part = part
	_update_candidate_details()


func _update_candidate_details() -> void:
	for button: Button in _candidate_parts:
		button.set_pressed_no_signal(_candidate_parts[button] == _pending_part)

	var equipped_part := _working_loadout.part_for_slot(_active_slot)
	var already_equipped := equipped_part == _pending_part
	_equip_button.disabled = already_equipped
	if already_equipped:
		_equip_button.text = "EQUIPPED"
	elif _pending_part == null:
		_equip_button.text = "REMOVE"
	else:
		_equip_button.text = "EQUIP"

	if _pending_part == null:
		_detail_name.text = "EMPTY MOUNT"
		_detail_kind.text = "NO COMPONENT"
		_detail_description.text = "Remove the component currently installed in this optional slot."
		_detail_stats.text = "ARMOR 0    WEIGHT 0\nPOWER +0   MOBILITY +0"
		_detail_weapon.text = "NO WEAPON LINK"
		return

	_detail_name.text = "%s // %s" % [_pending_part.designation, _pending_part.display_name]
	_detail_description.text = _pending_part.description
	_detail_stats.text = "ARMOR %.0f    WEIGHT %.0f\nPOWER %+.0f   MOBILITY %+.0f" % [
		_pending_part.armor,
		_pending_part.weight,
		_pending_part.power_generation - _pending_part.power_draw,
		_pending_part.mobility,
	]
	if _pending_part.part_type == MechPartSpec.PartType.HEAD:
		_detail_stats.text += "\nSENSOR %.0f / %.2fs   TRACK %d/%d" % [
			_pending_part.sensor_range,
			_pending_part.sensor_period,
			_pending_part.enemy_track_limit,
			_pending_part.projectile_track_limit,
		]
	if _pending_part.weapon == null:
		var type_name: String = MechPartSpec.PartType.keys()[_pending_part.part_type]
		_detail_kind.text = "SYSTEM // %s" % type_name
		_detail_weapon.text = "NO WEAPON LINK"
		return

	var weapon := _pending_part.weapon
	var family: String = WeaponSpec.WeaponFamily.keys()[weapon.weapon_family]
	_detail_kind.text = "WEAPON // %s" % family
	_detail_weapon.text = "RATE %.0f RPM   RANGE %.0f-%.0f\nMAG %d          RELOAD %.1fs" % [
		weapon.fire_rate * 60.0,
		weapon.effective_range,
		weapon.max_range,
		weapon.magazine_capacity,
		weapon.reload_duration,
	]


func _equip_pending_part() -> void:
	_select_part(_pending_part)


func _select_part(part: MechPartSpec) -> void:
	_working_loadout.set_part(_active_slot, part)
	_confirmed = false
	_overlay.visible = false
	_refresh()


func _close_part_picker() -> void:
	_overlay.visible = false


func _confirm_loadout() -> void:
	if not _working_loadout.is_valid():
		return
	GameSession.confirm_player_loadout(_working_loadout)
	_confirmed = true
	_confirm_button.disabled = true
	if not SceneTransition.transition_failed.is_connected(_on_scene_transition_failed):
		SceneTransition.transition_failed.connect(_on_scene_transition_failed)
	var scene_path := _deployment_scene_path()
	var error := SceneTransition.transition_to(scene_path)
	if error != OK:
		_confirm_button.disabled = false
		push_error("Unable to open combat scene: %s" % error_string(error))


func _return_to_main_menu() -> void:
	_confirm_button.disabled = true
	_main_menu_button.disabled = true
	if not SceneTransition.transition_failed.is_connected(_on_scene_transition_failed):
		SceneTransition.transition_failed.connect(_on_scene_transition_failed)
	var error := SceneTransition.transition_to(MAIN_MENU_SCENE_PATH)
	if error != OK:
		_confirm_button.disabled = false
		_main_menu_button.disabled = false
		push_error("Unable to open main menu: %s" % error_string(error))


func _on_scene_transition_failed(scene_path: String, error: Error) -> void:
	if scene_path not in [MAIN_MENU_SCENE_PATH, SKIRMISH_SCENE_PATH, ENDLESS_SCENE_PATH, STORY_STAGE_SELECT_PATH, GameSession.story_deployment_scene_path]:
		return
	_confirm_button.disabled = false
	_main_menu_button.disabled = false
	push_error("Unable to change scene: %s" % error_string(error))


func _deployment_scene_path() -> String:
	match GameSession.selected_game_mode:
		GameSession.GameMode.ENDLESS:
			return ENDLESS_SCENE_PATH
		GameSession.GameMode.STORY:
			return (
				GameSession.story_deployment_scene_path
				if not GameSession.story_deployment_scene_path.is_empty()
				else STORY_STAGE_SELECT_PATH
			)
	return SKIRMISH_SCENE_PATH


func _refresh() -> void:
	for slot in SLOT_ORDER:
		var button: Button = _slot_buttons[slot]
		var part := _working_loadout.part_for_slot(slot)
		var required := not _is_optional(slot)
		var marker := "*" if required else " "
		button.text = " %s %-9s  %s" % [marker, SLOT_NAMES[slot], part.designation if part != null else "-- EMPTY --"]

	mech_preview.display(_working_loadout)
	var totals := _working_loadout.stats()
	_set_stat("ARMOR", totals["armor"], "%.0f" % totals["armor"])
	_set_stat("FIREPOWER", totals["firepower"], "%.0f" % totals["firepower"])
	_set_stat("MOBILITY", maxf(totals["mobility"], 0.0), "%.0f" % totals["mobility"])
	_set_stat("COOLING", totals["cooling"], "%.0f" % totals["cooling"])
	var power_net: float = totals["power_generation"] - totals["power_draw"]
	_set_stat("POWER", clampf(power_net + 50.0, 0.0, 100.0), "%+.0f" % power_net)
	var capacity: float = totals["weight_capacity"]
	var weight_ratio: float = totals["weight"] / capacity * 100.0 if capacity > 0.0 else 100.0
	_set_stat("WEIGHT", weight_ratio, "%.0f/%.0f" % [totals["weight"], capacity])

	var errors := _working_loadout.validation_errors()
	_confirm_button.disabled = not errors.is_empty()
	if not errors.is_empty():
		_status_label.text = "INVALID"
		_status_label.add_theme_color_override("font_color", RED)
		_validation_label.text = errors[0]
	elif _confirmed:
		_status_label.text = "CONFIRMED"
		_status_label.add_theme_color_override("font_color", CYAN)
		_validation_label.text = "READY FOR BATTLE"
		_validation_label.add_theme_color_override("font_color", CYAN)
	else:
		_status_label.text = "EDITING"
		_status_label.add_theme_color_override("font_color", AMBER)
		_validation_label.text = "LOADOUT VALID"
		_validation_label.add_theme_color_override("font_color", TEXT)


func _set_stat(stat_name: String, value: float, value_text: String) -> void:
	var entry: Dictionary = _stat_bars[stat_name]
	var bar: ProgressBar = entry["bar"]
	bar.value = value
	var label: Label = entry["label"]
	label.text = value_text
	if stat_name == "WEIGHT":
		var color := RED if value > 100.0 else AMBER
		bar.add_theme_stylebox_override("fill", _style(color, color, 0))
	elif stat_name == "POWER":
		var color := RED if value < 50.0 else CYAN
		bar.add_theme_stylebox_override("fill", _style(color, color, 0))


func _part_type_for_slot(slot: MechLoadout.MechSlot) -> MechPartSpec.PartType:
	match slot:
		MechLoadout.MechSlot.HEAD:
			return MechPartSpec.PartType.HEAD
		MechLoadout.MechSlot.BODY:
			return MechPartSpec.PartType.BODY
		MechLoadout.MechSlot.LEFT_ARM, MechLoadout.MechSlot.RIGHT_ARM:
			return MechPartSpec.PartType.ARM_EQUIPMENT
		MechLoadout.MechSlot.BACKPACK:
			return MechPartSpec.PartType.BACKPACK
		MechLoadout.MechSlot.LEGS:
			return MechPartSpec.PartType.LEGS
	return MechPartSpec.PartType.BODY


func _is_optional(slot: MechLoadout.MechSlot) -> bool:
	return slot in [MechLoadout.MechSlot.LEFT_ARM, MechLoadout.MechSlot.RIGHT_ARM, MechLoadout.MechSlot.BACKPACK]


func _make_label(
	parent: Control,
	text: String,
	position: Vector2,
	size: Vector2,
	font_size: int,
	color: Color,
	alignment := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _style(fill: Color, border: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _overlay.visible:
		_close_part_picker()
		get_viewport().set_input_as_handled()
