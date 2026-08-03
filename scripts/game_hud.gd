class_name GameHud
extends Control

signal system_message_requested(text: String)

const NORMAL_COLOR := Color("a9c0ca")
const ACTIVE_COLOR := Color("66e6dc")
const WEAPON_SELECTED_COLOR := Color("62ed8c")
const HEAT_COLOR := Color("ff684f")
const BALLISTIC_AMMO_COLOR := Color("ff9f43")
const ENERGY_AMMO_COLOR := Color("73e0ff")
const MISSILE_AMMO_COLOR := Color("ffffff")
const AMMO_BAR_BACKGROUND := Color("14262e")
const AMMO_BAR_POSITION := Vector2(46.0, 101.0)
const AMMO_BAR_SIZE := Vector2(88.0, 2.0)
const WEAPON_SLOT_RECT := Rect2(32.0, 86.0, 103.0, 19.0)
const WIREFRAME_PREVIEW := preload("res://scripts/mech_wireframe_preview.gd")
const PART_NAMES: Array[StringName] = [
	&"Body", &"Head", &"Legs", &"LeftArm", &"RightArm", &"Backpack",
]

var player: AiMechAgent
var tactical_map: TacticalMap
var unit_status: Label
var weapon_status_labels: Array[Label] = []
var message_status: Label
var sensor_status: Label
var wireframe: MechWireframePreview
var energy_ratio := 1.0
var heat_ratio := 0.0


func _ready() -> void:
	_build_interface()
	set_process(false)


func bind(combat_player: AiMechAgent, allies: Array, enemies: Array, projectiles: Node2D) -> void:
	player = combat_player
	if player.mech_loadout != null:
		wireframe.display(player.mech_loadout)
	tactical_map.bind(player, allies, enemies, projectiles)
	player.hit_received.connect(_on_player_hit_received)
	player.part_destroyed.connect(_on_player_part_destroyed)
	player.hit_landed.connect(_on_player_hit_landed)
	player.parts_repaired.connect(_update_wireframe_durability)
	_update_wireframe_durability()
	set_process(true)


func set_roster(allies: Array, enemies: Array) -> void:
	tactical_map.set_roster(allies, enemies)


func set_resource_ratios(current_energy_ratio: float, current_heat_ratio: float) -> void:
	energy_ratio = clampf(current_energy_ratio, 0.0, 1.0)
	heat_ratio = clampf(current_heat_ratio, 0.0, 1.0)
	queue_redraw()


func _process(_delta: float) -> void:
	_update_unit_status()
	_update_sensor_status()
	_update_weapon_status()
	if is_instance_valid(player):
		set_resource_ratios(player.energy_ratio(), player.heat_ratio())
	queue_redraw()


func _build_interface() -> void:
	tactical_map = TacticalMap.new()
	tactical_map.position = Vector2(32.0, 11.0)
	tactical_map.size = Vector2(102.0, 64.0)
	add_child(tactical_map)

	wireframe = WIREFRAME_PREVIEW.new()
	wireframe.position = Vector2(83.0, 214.0)
	wireframe.display_sample()
	add_child(wireframe)

	for index in 4:
		var weapon_label := _make_label("%d  EMPTY" % (index + 1), 7, NORMAL_COLOR)
		weapon_label.position = Vector2(46.0, 81.0 + index * 21.0)
		weapon_label.size = Vector2(88.0, 19.0)
		weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(weapon_label)
		weapon_status_labels.append(weapon_label)

	unit_status = _make_label("FRAME // WAITING", 7, NORMAL_COLOR)
	unit_status.position = Vector2(36.0, 180.0)
	unit_status.size = Vector2(96.0, 10.0)
	add_child(unit_status)

	sensor_status = _make_label("SENSOR // OFFLINE", 6, NORMAL_COLOR)
	sensor_status.position = Vector2(36.0, 192.0)
	sensor_status.size = Vector2(96.0, 10.0)
	add_child(sensor_status)

	message_status = _make_label("SYSTEM READY", 6, NORMAL_COLOR)
	message_status.position = Vector2(35.0, 248.0)
	message_status.size = Vector2(98.0, 10.0)
	add_child(message_status)


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", -1)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _draw() -> void:
	_draw_resource_gauge(Rect2(8.0, 23.0, 10.0, 102.0), energy_ratio, ACTIVE_COLOR)
	_draw_resource_gauge(Rect2(8.0, 150.0, 10.0, 102.0), heat_ratio, HEAT_COLOR)
	_draw_weapon_ammo_bars()
	_draw_weapon_selection()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(7.0, 16.0), "EN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, ACTIVE_COLOR)
	draw_string(font, Vector2(4.0, 143.0), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5, HEAT_COLOR)


func _draw_resource_gauge(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color("020709"))
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var fill_height := floorf((rect.size.y - 2.0) * clamped_ratio)
	var fill_rect := Rect2(
		rect.position + Vector2(1.0, rect.size.y - 1.0 - fill_height),
		Vector2(rect.size.x - 2.0, fill_height)
	)
	draw_rect(fill_rect, color.darkened(0.55))
	for y in range(int(fill_rect.position.y), int(fill_rect.end.y), 4):
		draw_line(Vector2(fill_rect.position.x, y), Vector2(fill_rect.end.x, y), color, 1.0)


func _draw_weapon_ammo_bars() -> void:
	if not is_instance_valid(player):
		return
	var part_names: Array[StringName] = [&"LeftArm", &"RightArm", &"Backpack"]
	for index in part_names.size():
		var weapon := _weapon_for_part(part_names[index])
		if weapon == null:
			continue
		var bar_rect := Rect2(AMMO_BAR_POSITION + Vector2(0.0, index * 21.0), AMMO_BAR_SIZE)
		draw_rect(bar_rect, AMMO_BAR_BACKGROUND)
		var ammo_ratio: float
		var ammo_color := _weapon_ammo_color(weapon.spec.weapon_family)
		if weapon.disabled:
			continue
		if weapon.reload_remaining > 0.0:
			ammo_ratio = 1.0 - clampf(
				weapon.reload_remaining / maxf(weapon.reload_duration(), 0.001),
				0.0,
				1.0
			)
			ammo_color.a = 0.45
		else:
			ammo_ratio = clampf(
				float(weapon.ammo) / maxf(float(weapon.spec.magazine_capacity), 1.0),
				0.0,
				1.0
			)
		if ammo_ratio > 0.0:
			draw_rect(
				Rect2(bar_rect.position, Vector2(bar_rect.size.x * ammo_ratio, bar_rect.size.y)),
				ammo_color
			)


func _weapon_ammo_color(weapon_family: WeaponSpec.WeaponFamily) -> Color:
	match weapon_family:
		WeaponSpec.WeaponFamily.ENERGY:
			return ENERGY_AMMO_COLOR
		WeaponSpec.WeaponFamily.MISSILE:
			return MISSILE_AMMO_COLOR
		_:
			return BALLISTIC_AMMO_COLOR


func _draw_weapon_selection() -> void:
	if not is_instance_valid(player):
		return
	var selected_slots := [
		(player.selected_weapon_mask & AiMechAgent.WEAPON_SELECT_LEFT) != 0,
		(player.selected_weapon_mask & AiMechAgent.WEAPON_SELECT_RIGHT) != 0,
		(player.selected_weapon_mask & AiMechAgent.WEAPON_SELECT_BACKPACK) != 0,
		player.selected_weapon_mask == AiMechAgent.WEAPON_SELECT_ALL,
	]
	for index in selected_slots.size():
		if selected_slots[index]:
			var slot_rect := Rect2(
				WEAPON_SLOT_RECT.position + Vector2(0.0, index * 21.0),
				WEAPON_SLOT_RECT.size
			)
			draw_rect(slot_rect, WEAPON_SELECTED_COLOR, false, 1.0)

func _update_unit_status() -> void:
	if not is_instance_valid(player):
		return
	var last_hit := "NOMINAL"
	if not player.last_hit_part.is_empty():
		last_hit = "%s %d%%" % [
			player.last_hit_part,
			roundi(player.part_durability_ratio(player.last_hit_part) * 100.0),
		]
	unit_status.text = "FRAME // %s" % last_hit.to_upper()


func _update_sensor_status() -> void:
	if not is_instance_valid(player):
		return
	sensor_status.text = "S %.2fs  E%d/%d P%d/%d" % [
		player.sensor_period(),
		player.tracked_enemy_count(),
		player.enemy_track_limit(),
		player.tracked_projectile_count(),
		player.projectile_track_limit(),
	]


func _update_weapon_status() -> void:
	if not is_instance_valid(player):
		return
	var part_names: Array[StringName] = [&"LeftArm", &"RightArm", &"Backpack"]
	for index in part_names.size():
		var weapon := _weapon_for_part(part_names[index])
		if weapon == null:
			weapon_status_labels[index].text = "%d  EMPTY" % (index + 1)
			continue
		var resource := "--"
		if weapon.spec.resource_type == WeaponSpec.ResourceType.AMMO:
			resource = "%02d" % weapon.ammo
		var state := "RDY"
		if weapon.disabled:
			state = "OUT"
		elif weapon.reload_remaining > 0.0:
			state = "RLD"
		elif player.preparing_weapon_index == player.weapons.find(weapon):
			state = "PRE"
		elif weapon.cooldown_remaining > 0.0:
			state = "CD"
		var weapon_name := weapon.spec.display_name.to_upper().trim_prefix("TEST ").left(8)
		weapon_status_labels[index].text = "%d  %-8s %2s %s" % [index + 1, weapon_name, resource, state]
	weapon_status_labels[3].text = "4  ALL WEAPONS"


func _weapon_for_part(part_name: StringName) -> WeaponRuntime:
	for weapon in player.weapons:
		if weapon.part_name == part_name:
			return weapon
	return null


func _add_message(text_value: String) -> void:
	system_message_requested.emit(text_value)


func _on_player_hit_received(part_name: StringName, aspect: StringName) -> void:
	wireframe.set_part_durability(part_name, player.part_durability_ratio(part_name))
	var display_part := String(part_name).replace("Arm", " ARM").to_upper()
	_add_message("UNIT HIT: %s / %s" % [display_part, aspect])


func _on_player_part_destroyed(part_name: StringName) -> void:
	wireframe.set_part_state(part_name, MechWireframePreview.PartState.DESTROYED)
	var display_part := String(part_name).replace("Arm", " ARM").to_upper()
	_add_message("PART DESTROYED: %s" % display_part)


func _update_wireframe_durability() -> void:
	for part_name in PART_NAMES:
		if player.part_max_durability.has(part_name):
			wireframe.set_part_durability(part_name, player.part_durability_ratio(part_name))


func _on_player_hit_landed(weapon_family: WeaponSpec.WeaponFamily) -> void:
	var family_name: String = WeaponSpec.WeaponFamily.keys()[weapon_family]
	_add_message("ATTACK SUCCESS: %s" % family_name)
