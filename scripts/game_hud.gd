class_name GameHud
extends Control

const NORMAL_COLOR := Color("a9c0ca")
const ACTIVE_COLOR := Color("66e6dc")
const HEAT_COLOR := Color("ff684f")
const WIREFRAME_PREVIEW := preload("res://scripts/mech_wireframe_preview.gd")
const HIT_FLASH_DURATION := 0.8
const MESSAGE_DURATION := 4.0

var player: AiMechAgent
var projectile_layer: Node2D
var tactical_map: TacticalMap
var unit_status: Label
var weapon_status: Label
var message_status: Label
var wireframe: MechWireframePreview
var messages: Array[Dictionary] = []
var part_hit_timers := {}
var tracked_missiles := {}
var energy_ratio := 1.0
var heat_ratio := 0.0


func _ready() -> void:
	_build_interface()
	set_process(false)


func bind(combat_player: AiMechAgent, allies: Array, enemies: Array, projectiles: Node2D) -> void:
	player = combat_player
	projectile_layer = projectiles
	if player.mech_loadout != null:
		wireframe.display(player.mech_loadout)
	tactical_map.bind(player, allies, enemies, projectile_layer)
	player.hit_received.connect(_on_player_hit_received)
	player.hit_landed.connect(_on_player_hit_landed)
	_add_message("WASD MOVE / MOUSE AIM / LMB FIRE")
	set_process(true)


func set_resource_ratios(current_energy_ratio: float, current_heat_ratio: float) -> void:
	energy_ratio = clampf(current_energy_ratio, 0.0, 1.0)
	heat_ratio = clampf(current_heat_ratio, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_update_hit_timers(delta)
	_update_messages(delta)
	_detect_incoming_missiles()
	_update_unit_status()
	_update_weapon_status()
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

	weapon_status = _make_label("WEAPON LINK // WAITING", 7, NORMAL_COLOR)
	weapon_status.position = Vector2(45.0, 87.0)
	weapon_status.size = Vector2(88.0, 81.0)
	add_child(weapon_status)

	unit_status = _make_label("FRAME // WAITING", 7, NORMAL_COLOR)
	unit_status.position = Vector2(36.0, 180.0)
	unit_status.size = Vector2(96.0, 10.0)
	add_child(unit_status)

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


func _update_hit_timers(delta: float) -> void:
	for part_name in part_hit_timers.keys():
		var remaining: float = part_hit_timers[part_name] - delta
		if remaining <= 0.0:
			part_hit_timers.erase(part_name)
			wireframe.set_part_state(part_name, MechWireframePreview.PartState.HEALTHY)
		else:
			part_hit_timers[part_name] = remaining


func _update_unit_status() -> void:
	if not is_instance_valid(player):
		return
	var last_hit := "NOMINAL"
	if not player.last_hit_part.is_empty():
		last_hit = "%s %s" % [player.last_hit_part, player.last_hit_aspect]
	unit_status.text = "FRAME // %s" % last_hit.to_upper()


func _update_weapon_status() -> void:
	if not is_instance_valid(player):
		return
	var rows := PackedStringArray()
	for index in 4:
		if index >= player.weapons.size():
			rows.append("%d  EMPTY" % (index + 1))
			continue
		var weapon := player.weapons[index]
		var resource := "--"
		if weapon.spec.resource_type == WeaponSpec.ResourceType.AMMO:
			resource = "%02d" % weapon.ammo
		var state := "RDY"
		if weapon.reload_remaining > 0.0:
			state = "RLD"
		elif player.preparing_weapon_index == index:
			state = "PRE"
		elif weapon.cooldown_remaining > 0.0:
			state = "CD"
		var weapon_name := weapon.spec.display_name.to_upper().trim_prefix("TEST ").left(8)
		rows.append("%d  %-8s %2s %s" % [index + 1, weapon_name, resource, state])
	weapon_status.text = "\n".join(rows)


func _update_messages(delta: float) -> void:
	for index in range(messages.size() - 1, -1, -1):
		messages[index]["remaining"] = float(messages[index]["remaining"]) - delta
		if float(messages[index]["remaining"]) <= 0.0:
			messages.remove_at(index)
	message_status.text = "SYSTEM READY" if messages.is_empty() else String(messages.back()["text"])


func _detect_incoming_missiles() -> void:
	if not is_instance_valid(projectile_layer):
		return
	var active := {}
	for node in projectile_layer.get_children():
		var projectile := node as BallisticProjectile
		if (
			projectile == null
			or projectile.weapon_family != WeaponSpec.WeaponFamily.MISSILE
			or projectile.homing_target != player
		):
			continue
		var instance_id := projectile.get_instance_id()
		active[instance_id] = true
		if not tracked_missiles.has(instance_id):
			_add_message("MISSILE DETECTED")
	tracked_missiles = active


func _add_message(text_value: String) -> void:
	messages.append({"text": text_value, "remaining": MESSAGE_DURATION})
	if messages.size() > 8:
		messages.pop_front()


func _on_player_hit_received(part_name: StringName, aspect: StringName) -> void:
	part_hit_timers[part_name] = HIT_FLASH_DURATION
	wireframe.set_part_state(part_name, MechWireframePreview.PartState.DAMAGED)
	var display_part := String(part_name).replace("Arm", " ARM").to_upper()
	_add_message("UNIT HIT: %s / %s" % [display_part, aspect])


func _on_player_hit_landed(weapon_family: WeaponSpec.WeaponFamily) -> void:
	var family_name: String = WeaponSpec.WeaponFamily.keys()[weapon_family]
	_add_message("ATTACK SUCCESS: %s" % family_name)
