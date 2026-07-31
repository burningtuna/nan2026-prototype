extends Node2D

const AnchorMap := preload("res://scripts/sprite_anchor_map.gd")
const TEST_CANNON := preload("res://data/test_cannon.tres")
const MUZZLE_FLASH_SCENE := preload("res://scenes/muzzle_flash.tscn")

const BODY_ART := "res://Sprites/Body-0001.png"
const BODY_ANCHORS := "res://Sprites/Body-0001.anchors.png"
const HEAD_ART := "res://Sprites/Head-0001.png"
const HEAD_ANCHORS := "res://Sprites/Head-0001.anchors.png"
const LEGS_ART := "res://Sprites/Legs-0001.png"
const LEGS_ANCHORS := "res://Sprites/Legs-0001.anchors.png"
const ARM_ART := "res://Sprites/Arm-Cannon-0001.png"
const ARM_ANCHORS := "res://Sprites/Arm-Cannon-0001.anchors.png"
const BACKPACK_ART := "res://Sprites/Backpack-Generator-0001.png"
const BACKPACK_ANCHORS := "res://Sprites/Backpack-Generator-0001.anchors.png"
const BOOST_FRAMES := [
	"res://Sprites/Boost-0001.png",
	"res://Sprites/Boost-0002.png",
	"res://Sprites/Boost-0003.png",
]
const DASH_FRAMES := [
	"res://Sprites/Dash-0001.png",
	"res://Sprites/Dash-0002.png",
	"res://Sprites/Dash-0003.png",
]

@export var cruise_speed := 70.0
@export var boost_speed := 120.0
@export var acceleration := 220.0
@export var boost_acceleration := 360.0
@export var deceleration := 180.0
@export var upper_turn_speed_degrees := 30.0
@export var dash_speed := 140.0
@export var dash_duration := 0.5
@export var dash_cooldown := 1.0
@export var dash_heat_cost := 30.0
@export var heat_cooling_per_second := 8.0
@export var dash_effect_offset := 10.0
@export var linked_fire_stagger := 0.12

@onready var mech: Node2D = $Mech
@onready var lower_body: Node2D = $Mech/LowerBody
@onready var upper_body: Node2D = $Mech/UpperBody
@onready var projectile_layer: Node2D = $Projectiles
@onready var status_label: Label = $UI/Status
@onready var weapon_status_label: Label = $UI/WeaponStatus

var arm_aim_nodes: Array[Node2D] = []
var weapons: Array[WeaponRuntime] = []
var head_aim_node: Node2D
var boost_sprites: Array[AnimatedSprite2D] = []
var dash_sprite: AnimatedSprite2D
var velocity := Vector2.ZERO
var boost_active := false
var mouse_aim_active := false
var dash_direction := Vector2.ZERO
var dash_side := 0.0
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var heat := 0.0
var linked_fire_cooldown := 0.0
var next_weapon_index := 0
var shot_sequence := 0
var shot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	shot_rng.seed = 0xD1CE12
	_build_mech()
	_center_mech()
	get_viewport().size_changed.connect(_center_mech)
	_update_status()
	queue_redraw()


func _process(_delta: float) -> void:
	if not mouse_aim_active:
		return

	var mouse_position := get_global_mouse_position()
	var head_aim_vector := mouse_position - head_aim_node.global_position
	if head_aim_vector.length_squared() > 4.0:
		# Head art faces up (-Y), while cannon art faces right (+X).
		head_aim_node.global_rotation = head_aim_vector.angle() + PI * 0.5

	for aim_node in arm_aim_nodes:
		var aim_vector := mouse_position - aim_node.global_position
		if aim_vector.length_squared() > 4.0:
			aim_node.global_rotation = aim_vector.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_weapons(delta)
	var input_direction := _get_move_input()
	var dashing := dash_time_remaining > 0.0
	boost_active = not dashing and not input_direction.is_zero_approx() and Input.is_key_pressed(KEY_SPACE)

	if dashing:
		var dash_step := minf(delta, dash_time_remaining)
		mech.position += velocity * delta + dash_direction * dash_speed * dash_step
		dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
		if dash_time_remaining <= 0.0:
			_finish_dash()
	else:
		var target_speed := boost_speed if boost_active else cruise_speed
		var target_velocity := input_direction * target_speed
		var current_acceleration := boost_acceleration if boost_active else acceleration
		var velocity_change := current_acceleration if not input_direction.is_zero_approx() else deceleration
		velocity = velocity.move_toward(target_velocity, velocity_change * delta)
		mech.position += velocity * delta

		if not input_direction.is_zero_approx():
			# Lower-body art faces up (-Y), so add 90 degrees to the world vector.
			lower_body.rotation = input_direction.angle() + PI * 0.5

		dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)

	heat = move_toward(heat, 0.0, heat_cooling_per_second * delta)
	_clamp_mech_to_viewport()

	_rotate_upper_body(delta)
	_update_boost_effect(input_direction, dashing)
	_update_status()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_aim_active = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_try_start_dash(-1.0)
		elif event.keycode == KEY_C:
			_try_start_dash(1.0)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("111820"))

	for x in range(0, int(viewport_size.x) + 1, 16):
		draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), Color("18232d"))
	for y in range(0, int(viewport_size.y) + 1, 16):
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), Color("18232d"))

	draw_circle(mech.position, 52.0, Color("243541"), false, 1.0)
	draw_circle(mech.position, 68.0, Color("1b2a34"), false, 1.0)

	var cursor := get_local_mouse_position()
	draw_line(cursor + Vector2(-5, 0), cursor + Vector2(5, 0), Color("d95757"), 1.0)
	draw_line(cursor + Vector2(0, -5), cursor + Vector2(0, 5), Color("d95757"), 1.0)


func _build_mech() -> void:
	var body_map := AnchorMap.load_map(BODY_ANCHORS)
	var body_sprite := _create_sprite(BODY_ART, 2)
	body_sprite.name = "BodySprite"
	upper_body.add_child(body_sprite)
	_attach_dash_effect()

	var backpack_socket := AnchorMap.one(body_map, &"backpack_socket")
	_attach_static_part(upper_body, "Backpack", BACKPACK_ART, BACKPACK_ANCHORS, backpack_socket, -2)

	var legs_socket := AnchorMap.one(body_map, &"legs_socket")
	var legs := _attach_static_part(lower_body, "Legs", LEGS_ART, LEGS_ANCHORS, legs_socket, -1)
	_attach_boosts(legs)

	var head_socket := AnchorMap.one(body_map, &"head_socket")
	head_aim_node = _attach_rotating_head(upper_body, head_socket, 4)

	var left_arm_socket := AnchorMap.one(body_map, &"left_arm_socket")
	var left_arm := _attach_aiming_arm(upper_body, "LeftArm", left_arm_socket, 3)
	arm_aim_nodes.append(left_arm["aim"] as Node2D)
	weapons.append(left_arm["weapon"] as WeaponRuntime)

	var right_arm_socket := AnchorMap.one(body_map, &"right_arm_socket")
	var right_arm := _attach_aiming_arm(upper_body, "RightArm", right_arm_socket, 3)
	arm_aim_nodes.append(right_arm["aim"] as Node2D)
	weapons.append(right_arm["weapon"] as WeaponRuntime)


func _attach_static_part(
	parent: Node2D,
	part_name: String,
	art_path: String,
	anchor_path: String,
	socket_position: Vector2,
	z_index: int
) -> Dictionary:
	var anchor_map := AnchorMap.load_map(anchor_path)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var part_root := Node2D.new()
	part_root.name = part_name
	part_root.position = socket_position
	parent.add_child(part_root)

	var sprite := _create_sprite(art_path, z_index)
	sprite.name = "%sSprite" % part_name
	sprite.position = -mount
	part_root.add_child(sprite)

	return {
		"root": part_root,
		"map": anchor_map,
		"mount": mount,
	}


func _attach_aiming_arm(
	parent: Node2D,
	part_name: String,
	socket_position: Vector2,
	z_index: int
) -> Dictionary:
	var anchor_map := AnchorMap.load_map(ARM_ANCHORS)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_pivot := AnchorMap.one(anchor_map, &"aim_pivot")

	var mount_root := Node2D.new()
	mount_root.name = "%sMount" % part_name
	mount_root.position = socket_position
	parent.add_child(mount_root)

	var aim_node := Node2D.new()
	aim_node.name = "%sAimPivot" % part_name
	aim_node.position = aim_pivot - mount
	aim_node.rotation = -PI * 0.5
	mount_root.add_child(aim_node)

	var sprite := _create_sprite(ARM_ART, z_index)
	sprite.name = "%sSprite" % part_name
	sprite.position = -aim_pivot
	aim_node.add_child(sprite)

	var muzzles: Array[Marker2D] = []
	var muzzle_positions := AnchorMap.many(anchor_map, &"muzzle")
	for index in muzzle_positions.size():
		var muzzle := Marker2D.new()
		muzzle.name = "Muzzle%d" % (index + 1)
		muzzle.position = muzzle_positions[index] - aim_pivot
		aim_node.add_child(muzzle)
		muzzles.append(muzzle)

	var weapon := WeaponRuntime.new()
	weapon.setup(TEST_CANNON, sprite, muzzles, StringName(part_name))
	return {
		"aim": aim_node,
		"weapon": weapon,
	}


func _attach_rotating_head(parent: Node2D, socket_position: Vector2, z_index: int) -> Node2D:
	var anchor_map := AnchorMap.load_map(HEAD_ANCHORS)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_node := Node2D.new()
	aim_node.name = "HeadAimPivot"
	aim_node.position = socket_position
	parent.add_child(aim_node)

	var sprite := _create_sprite(HEAD_ART, z_index)
	sprite.name = "HeadSprite"
	sprite.position = -mount
	aim_node.add_child(sprite)

	return aim_node


func _attach_boosts(legs: Dictionary) -> void:
	var legs_root := legs["root"] as Node2D
	var legs_map: Dictionary = legs["map"]
	var legs_mount: Vector2 = legs["mount"]
	var frames := SpriteFrames.new()
	frames.add_animation(&"burn")
	frames.set_animation_loop(&"burn", true)
	frames.set_animation_speed(&"burn", 8.0)

	for texture_path in BOOST_FRAMES:
		frames.add_frame(&"burn", load(texture_path) as Texture2D)

	var boost_anchors := AnchorMap.many(legs_map, &"boost")
	for index in boost_anchors.size():
		var boost_anchor := boost_anchors[index]
		var boost := AnimatedSprite2D.new()
		boost.name = "Boost%d" % (index + 1)
		boost.sprite_frames = frames
		boost.animation = &"burn"
		boost.position = boost_anchor - legs_mount + Vector2(0, 2.5)
		boost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		boost.z_index = -2
		boost.visible = false
		legs_root.add_child(boost)
		boost.play()
		boost_sprites.append(boost)


func _attach_dash_effect() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"dash")
	frames.set_animation_loop(&"dash", true)
	frames.set_animation_speed(&"dash", 14.0)

	for texture_path in DASH_FRAMES:
		frames.add_frame(&"dash", load(texture_path) as Texture2D)

	dash_sprite = AnimatedSprite2D.new()
	dash_sprite.name = "DashEffect"
	dash_sprite.sprite_frames = frames
	dash_sprite.animation = &"dash"
	dash_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dash_sprite.z_index = 1
	dash_sprite.visible = false
	mech.add_child(dash_sprite)
	dash_sprite.play()


func _create_sprite(texture_path: String, z_index: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index
	return sprite


func _center_mech() -> void:
	mech.position = get_viewport_rect().size * 0.5


func _get_move_input() -> Vector2:
	var input_direction := Vector2(
		(1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0),
		(1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0)
	)
	return input_direction.normalized() if input_direction.length_squared() > 1.0 else input_direction


func _rotate_upper_body(delta: float) -> void:
	var target_rotation := lower_body.global_rotation
	if mouse_aim_active:
		var aim_vector := get_global_mouse_position() - upper_body.global_position
		if aim_vector.length_squared() > 4.0:
			target_rotation = aim_vector.angle() + PI * 0.5

	upper_body.global_rotation = rotate_toward(
		upper_body.global_rotation,
		target_rotation,
		deg_to_rad(upper_turn_speed_degrees) * delta
	)


func _update_boost_effect(input_direction: Vector2, dashing: bool) -> void:
	var thrusting := not dashing and not input_direction.is_zero_approx()
	for boost_sprite in boost_sprites:
		boost_sprite.visible = thrusting
		boost_sprite.speed_scale = 1.75 if boost_active else 1.0
		boost_sprite.scale = Vector2(1.0, 1.5 if boost_active else 1.0)


func _try_start_dash(side: float) -> void:
	if dash_time_remaining > 0.0 or dash_cooldown_remaining > 0.0:
		return

	dash_side = side
	# UpperBody's local +X is the torso's right side. Keep this direction fixed
	# for the whole dash while leaving lower-body facing unchanged.
	dash_direction = upper_body.global_transform.x.normalized() * dash_side
	dash_time_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	heat = minf(heat + dash_heat_cost, 100.0)
	_set_dash_effect(true)


func _finish_dash() -> void:
	dash_time_remaining = 0.0
	dash_side = 0.0
	dash_direction = Vector2.ZERO
	_set_dash_effect(false)


func _set_dash_effect(enabled: bool) -> void:
	if enabled:
		# Exhaust points opposite the dash. With a forward-facing torso this is
		# 270 degrees for a left dash and 90 degrees for a right dash.
		var exhaust_direction := Vector2.RIGHT.rotated(upper_body.rotation) * -dash_side
		dash_sprite.rotation = exhaust_direction.angle() - PI * 0.5
		dash_sprite.position = exhaust_direction * dash_effect_offset
		dash_sprite.frame = 0
	dash_sprite.visible = enabled


func _update_weapons(delta: float) -> void:
	for weapon in weapons:
		weapon.tick(delta)
	linked_fire_cooldown = maxf(linked_fire_cooldown - delta, 0.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire_linked_group()
	_update_weapon_status()


func _try_fire_linked_group() -> void:
	if linked_fire_cooldown > 0.0 or weapons.is_empty():
		return

	for offset in weapons.size():
		var weapon_index := (next_weapon_index + offset) % weapons.size()
		var weapon := weapons[weapon_index]
		if not weapon.can_fire():
			continue
		_fire_weapon(weapon)
		next_weapon_index = (weapon_index + 1) % weapons.size()
		linked_fire_cooldown = linked_fire_stagger
		return


func _fire_weapon(weapon: WeaponRuntime) -> void:
	var muzzle := weapon.fire()
	if muzzle == null:
		return

	var aim_position := get_global_mouse_position()
	var aim_vector := aim_position - muzzle.global_position
	if aim_vector.length_squared() <= 1.0:
		aim_vector = muzzle.global_transform.x

	var aim_distance := aim_vector.length()
	var spread_degrees := weapon.spec.spread_at_distance(aim_distance)
	var shot_seed := shot_rng.randi()
	var spread_angle := deg_to_rad(shot_rng.randf_range(-spread_degrees, spread_degrees))
	var launch_direction := aim_vector.normalized().rotated(spread_angle)
	_spawn_projectile(weapon, muzzle.global_position, launch_direction, shot_seed, spread_degrees)
	_spawn_muzzle_flash(weapon.spec, muzzle.global_position, launch_direction)


func _spawn_projectile(
	weapon: WeaponRuntime,
	spawn_position: Vector2,
	direction: Vector2,
	shot_seed: int,
	spread_degrees: float
) -> void:
	var projectile_spec := weapon.spec.projectile
	var projectile := projectile_spec.projectile_scene.instantiate() as BallisticProjectile
	projectile.configure(
		projectile_spec,
		direction,
		weapon.spec.max_range,
		mech,
		weapon.part_name,
		shot_seed,
		spread_degrees
	)
	projectile_layer.add_child(projectile)
	projectile.global_position = spawn_position
	shot_sequence += 1


func _spawn_muzzle_flash(
	weapon_spec: WeaponSpec,
	spawn_position: Vector2,
	direction: Vector2
) -> void:
	var flash := MUZZLE_FLASH_SCENE.instantiate() as MuzzleFlash
	flash.setup(
		direction,
		weapon_spec.muzzle_flash_color,
		weapon_spec.muzzle_flash_duration,
		weapon_spec.fire_effect_id
	)
	projectile_layer.add_child(flash)
	flash.global_position = spawn_position


func _clamp_mech_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var margin := 28.0
	mech.position = mech.position.clamp(
		Vector2(margin, margin),
		viewport_size - Vector2(margin, margin)
	)


func _update_status() -> void:
	var dash_status := "READY"
	if dash_time_remaining > 0.0:
		dash_status = "LEFT" if dash_side < 0.0 else "RIGHT"
	elif dash_cooldown_remaining > 0.0:
		dash_status = "%.1fs" % dash_cooldown_remaining

	status_label.text = "SPD %3d  HEAT %3d  LOWER %3d°  BOOST %s  DASH %s" % [
		roundi(velocity.length()),
		roundi(heat),
		roundi(fposmod(rad_to_deg(lower_body.rotation), 360.0)),
		"ON" if boost_active else "OFF",
		dash_status,
	]


func _update_weapon_status() -> void:
	if weapons.size() < 2:
		weapon_status_label.text = "WEAPONS: INITIALIZING"
		return
	weapon_status_label.text = "L %02d/%02d   R %02d/%02d   NEXT %s   SHOTS %d" % [
		weapons[0].ammo,
		weapons[0].spec.ammo_capacity,
		weapons[1].ammo,
		weapons[1].spec.ammo_capacity,
		"L" if next_weapon_index == 0 else "R",
		shot_sequence,
	]
