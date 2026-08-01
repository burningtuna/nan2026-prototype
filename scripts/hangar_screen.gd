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

@onready var mech_preview: MechPreview = $MechPreview

var _catalog: Dictionary = {}
var _working_loadout: MechLoadout
var _slot_buttons: Dictionary = {}
var _stat_bars: Dictionary = {}
var _status_label: Label
var _validation_label: Label
var _confirm_button: Button
var _overlay: Control
var _overlay_title: Label
var _candidate_list: VBoxContainer
var _active_slot := MechLoadout.MechSlot.BODY
var _confirmed := false


func _ready() -> void:
	_build_catalog()
	_working_loadout = _initial_loadout()
	_build_interface()
	_refresh()
	queue_redraw()


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
	_make_label(self, "DIRECTIVE//12", Vector2(9, 5), Vector2(130, 18), 14, CYAN)
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
	_make_label(self, "TOP-DOWN ASSEMBLY PREVIEW", Vector2(255, 169), Vector2(162, 11), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

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
		bar.position = origin + Vector2(0, 10)
		bar.size = Vector2(106, 7)
		bar.max_value = stat_defs[index][1]
		bar.show_percentage = false
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
	_confirm_button.add_theme_font_size_override("font_size", 8)
	_confirm_button.add_theme_color_override("font_color", BG)
	_confirm_button.add_theme_color_override("font_disabled_color", MUTED)
	_confirm_button.add_theme_stylebox_override("normal", _style(CYAN, CYAN))
	_confirm_button.add_theme_stylebox_override("hover", _style(Color("8ff9e9"), Color("8ff9e9")))
	_confirm_button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER))
	_confirm_button.add_theme_stylebox_override("disabled", _style(Color("17282d"), LINE))
	_confirm_button.pressed.connect(_confirm_loadout)
	add_child(_confirm_button)

	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.04, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(67, 35)
	panel.size = Vector2(346, 200)
	panel.add_theme_stylebox_override("panel", _style(PANEL_ALT, CYAN, 2))
	_overlay.add_child(panel)

	_overlay_title = _make_label(panel, "SELECT PART", Vector2(12, 9), Vector2(270, 17), 11, CYAN)
	_make_label(panel, "AVAILABLE COMPONENTS / CLICK TO EQUIP", Vector2(12, 27), Vector2(260, 12), 7, MUTED)

	var close := Button.new()
	close.position = Vector2(312, 8)
	close.size = Vector2(24, 18)
	close.text = "X"
	close.add_theme_font_size_override("font_size", 9)
	close.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	close.add_theme_stylebox_override("hover", _style(Color("351a1a"), RED))
	close.pressed.connect(_close_part_picker)
	panel.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 45)
	scroll.size = Vector2(322, 142)
	panel.add_child(scroll)
	_candidate_list = VBoxContainer.new()
	_candidate_list.custom_minimum_size = Vector2(312, 0)
	_candidate_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_candidate_list)


func _build_catalog() -> void:
	var body_art := "res://Sprites/Body-0001.png"
	var body_anchors := "res://Sprites/Body-0001.anchors.png"
	var head_art := "res://Sprites/Head-0001.png"
	var head_anchors := "res://Sprites/Head-0001.anchors.png"
	var legs_art := "res://Sprites/Legs-0001.png"
	var legs_anchors := "res://Sprites/Legs-0001.anchors.png"
	var arm_art := "res://Sprites/Arm-Cannon-0001.png"
	var arm_anchors := "res://Sprites/Arm-Cannon-0001.anchors.png"
	var pack_art := "res://Sprites/Backpack-Generator-0001.png"
	var pack_anchors := "res://Sprites/Backpack-Generator-0001.anchors.png"

	_catalog[MechPartSpec.PartType.BODY] = [
		_make_part("KESTREL CORE", "BD-01", "Balanced lightweight combat core.", MechPartSpec.PartType.BODY, body_art, body_anchors, Color("ffffff"), 150, 12, 15, 8, 12, 4, 0, 0),
		_make_part("BULWARK CORE", "BD-04", "Heavy core with reinforced plating.", MechPartSpec.PartType.BODY, body_art, body_anchors, Color("b6d2d5"), 230, 21, 18, 12, 8, -4, 0, 0),
	]
	_catalog[MechPartSpec.PartType.HEAD] = [
		_make_part("RAVEN SENSOR", "HD-02", "Fast acquisition sensor crown.", MechPartSpec.PartType.HEAD, head_art, head_anchors, Color("ffffff"), 55, 4, 0, 5, 6, 8, 0, 0),
		_make_part("BASTION ARRAY", "HD-07", "Armored command and targeting array.", MechPartSpec.PartType.HEAD, head_art, head_anchors, Color("ffd28b"), 90, 7, 0, 7, 4, 2, 0, 0),
	]
	_catalog[MechPartSpec.PartType.LEGS] = [
		_make_part("STRIDER LEGS", "LG-03", "High-output vector drive assembly.", MechPartSpec.PartType.LEGS, legs_art, legs_anchors, Color("ffffff"), 110, 11, 0, 10, 3, 62, 0, 58),
		_make_part("ANVIL LEGS", "LG-08", "Stable heavy-duty load platform.", MechPartSpec.PartType.LEGS, legs_art, legs_anchors, Color("a8c7bf"), 180, 18, 0, 13, 5, 36, 0, 78),
	]
	_catalog[MechPartSpec.PartType.ARM_EQUIPMENT] = [
		_make_part("RX AUTOCANNON", "AR-11", "Reliable ballistic arm weapon.", MechPartSpec.PartType.ARM_EQUIPMENT, arm_art, arm_anchors, Color("ffffff"), 48, 9, 0, 8, 0, -2, 42, 0, preload("res://data/test_cannon.tres")),
		_make_part("TEMPEST ROCKET", "AR-15", "Single-shot guided rocket system.", MechPartSpec.PartType.ARM_EQUIPMENT, arm_art, arm_anchors, Color("ffd28b"), 40, 7, 0, 6, 0, 0, 58, 0, preload("res://data/test_missile.tres")),
		_make_part("ARC PULSE", "AR-22", "Compact pulse-energy projector.", MechPartSpec.PartType.ARM_EQUIPMENT, arm_art, arm_anchors, Color("9bdfff"), 36, 6, 0, 15, 0, 2, 52, 0, preload("res://data/test_energy_cannon.tres")),
		_make_part("BREACH CANNON", "AR-31", "Heavy five-round kinetic cannon.", MechPartSpec.PartType.ARM_EQUIPMENT, arm_art, arm_anchors, Color("ff9c87"), 65, 14, 0, 11, 0, -7, 74, 0, preload("res://data/test_burst_cannon.tres")),
	]
	_catalog[MechPartSpec.PartType.BACKPACK] = [
		_make_part("GRID GENERATOR", "BP-05", "Auxiliary generator for high-draw parts.", MechPartSpec.PartType.BACKPACK, pack_art, pack_anchors, Color("ffffff"), 55, 8, 38, 2, 6, -2, 0, 0),
		_make_part("HEAT SINK ARRAY", "BP-09", "Large thermal dissipation package.", MechPartSpec.PartType.BACKPACK, pack_art, pack_anchors, Color("9bdfff"), 45, 7, 6, 4, 35, 0, 0, 0),
		_make_part("TEMPEST RACK", "BP-16", "Back-mounted guided missile rack.", MechPartSpec.PartType.BACKPACK, pack_art, pack_anchors, Color("ffd28b"), 38, 10, 0, 9, 0, -4, 48, 0, preload("res://data/test_missile.tres")),
	]


func _make_part(
	name: String,
	designation: String,
	description: String,
	type: MechPartSpec.PartType,
	art_path: String,
	anchor_path: String,
	tint: Color,
	armor: float,
	weight: float,
	generation: float,
	power_draw: float,
	cooling: float,
	mobility: float,
	firepower: float,
	capacity: float,
	weapon: WeaponSpec = null
) -> MechPartSpec:
	var part := MechPartSpec.new()
	part.display_name = name
	part.designation = designation
	part.description = description
	part.part_type = type
	part.art_path = art_path
	part.anchor_path = anchor_path
	part.preview_tint = tint
	part.armor = armor
	part.weight = weight
	part.power_generation = generation
	part.power_draw = power_draw
	part.cooling = cooling
	part.mobility = mobility
	part.firepower = firepower
	part.weight_capacity = capacity
	part.weapon = weapon
	return part


func _initial_loadout() -> MechLoadout:
	if GameSession.player_mech_loadout != null:
		return GameSession.player_mech_loadout.copy()
	var loadout := MechLoadout.new()
	loadout.body = _catalog[MechPartSpec.PartType.BODY][0]
	loadout.head = _catalog[MechPartSpec.PartType.HEAD][0]
	loadout.legs = _catalog[MechPartSpec.PartType.LEGS][0]
	loadout.left_arm = _catalog[MechPartSpec.PartType.ARM_EQUIPMENT][0]
	loadout.backpack = _catalog[MechPartSpec.PartType.BACKPACK][0]
	return loadout


func _open_part_picker(slot: MechLoadout.MechSlot) -> void:
	_active_slot = slot
	_overlay_title.text = "SELECT // %s" % SLOT_NAMES[slot]
	for child in _candidate_list.get_children():
		_candidate_list.remove_child(child)
		child.queue_free()

	if _is_optional(slot):
		_add_candidate_button(null)
	var expected_type := _part_type_for_slot(slot)
	for part: MechPartSpec in _catalog.get(expected_type, []):
		_add_candidate_button(part)
	_overlay.visible = true


func _add_candidate_button(part: MechPartSpec) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(312, 27)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
	if part == null:
		button.text = "  -- EMPTY MOUNT --\n     REMOVE EQUIPPED COMPONENT"
		button.add_theme_color_override("font_color", MUTED)
	else:
		button.text = "  %s  //  %s\n     ARM %d   WT %.0f   PWR %+.0f   FP %.0f" % [part.designation, part.display_name, part.armor, part.weight, part.power_generation - part.power_draw, part.firepower]
		button.tooltip_text = part.description
	button.pressed.connect(_select_part.bind(part))
	_candidate_list.add_child(button)


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
	_refresh()


func _refresh() -> void:
	for slot in SLOT_ORDER:
		var button: Button = _slot_buttons[slot]
		var part := _working_loadout.part_for_slot(slot)
		var required := not _is_optional(slot)
		var marker := "*" if required else " "
		button.text = " %s %-9s  %s" % [marker, SLOT_NAMES[slot], part.designation if part != null else "-- EMPTY --"]
		button.tooltip_text = part.display_name if part != null else "Empty optional mount"

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
