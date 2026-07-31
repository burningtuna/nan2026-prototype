class_name AiMechAgent
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

@export var cruise_speed := 70.0
@export var acceleration := 180.0
@export var upper_turn_speed_degrees := 120.0
@export var linked_fire_stagger := 0.12
@export var reload_duration := 2.0

var opponent: AiMechAgent
var velocity := Vector2.ZERO
var shot_count := 0

var arena := Rect2(-360.0, -220.0, 720.0, 440.0)
var projectile_layer: Node2D
var lower_body: Node2D
var upper_body: Node2D
var head_aim_node: Node2D
var arm_aim_nodes: Array[Node2D] = []
var boost_sprites: Array[AnimatedSprite2D] = []
var weapons: Array[WeaponRuntime] = []
var movement_direction := Vector2.ZERO
var direction_time_remaining := 0.0
var linked_fire_cooldown := 0.0
var reload_time_remaining := 0.0
var next_weapon_index := 0
var rng := RandomNumberGenerator.new()


func setup(
	agent_name: String,
	shot_parent: Node2D,
	movement_arena: Rect2,
	random_seed: int,
	team_color: Color
) -> void:
	name = agent_name
	projectile_layer = shot_parent
	arena = movement_arena
	rng.seed = random_seed
	modulate = team_color
	scale = Vector2.ONE * 4.0


func set_opponent(target: AiMechAgent) -> void:
	opponent = target


func ammo_remaining() -> int:
	var total := 0
	for weapon in weapons:
		total += weapon.ammo
	return total


func _ready() -> void:
	lower_body = Node2D.new()
	lower_body.name = "LowerBody"
	add_child(lower_body)

	upper_body = Node2D.new()
	upper_body.name = "UpperBody"
	add_child(upper_body)

	_build_mech()
	_choose_direction()


func _physics_process(delta: float) -> void:
	_update_random_movement(delta)
	_aim_at_opponent(delta)
	_update_weapons(delta)
	_update_boost_effect()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color(0.2, 0.34, 0.42, 0.75), false, 0.25)
	draw_circle(Vector2.ZERO, 17.0, Color(0.12, 0.22, 0.28, 0.65), false, 0.25)


func _update_random_movement(delta: float) -> void:
	direction_time_remaining -= delta
	if direction_time_remaining <= 0.0:
		_choose_direction()

	var margin := 45.0
	var safe_arena := arena.grow(-margin)
	if not safe_arena.has_point(position):
		movement_direction = (arena.get_center() - position).normalized()
		direction_time_remaining = minf(direction_time_remaining, 0.6)

	var target_velocity := movement_direction * cruise_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	position += velocity * delta
	position = position.clamp(arena.position, arena.end)

	if velocity.length_squared() > 4.0:
		lower_body.rotation = velocity.angle() + PI * 0.5


func _choose_direction() -> void:
	var random_angle := rng.randf_range(-PI, PI)
	movement_direction = Vector2.from_angle(random_angle)
	direction_time_remaining = rng.randf_range(0.8, 2.2)

	var center_pull := arena.get_center() - position
	if center_pull.length() > minf(arena.size.x, arena.size.y) * 0.35:
		movement_direction = (movement_direction + center_pull.normalized() * 0.8).normalized()


func _aim_at_opponent(delta: float) -> void:
	if not is_instance_valid(opponent):
		return

	var target_vector := opponent.global_position - upper_body.global_position
	if target_vector.length_squared() <= 4.0:
		return

	upper_body.global_rotation = rotate_toward(
		upper_body.global_rotation,
		target_vector.angle() + PI * 0.5,
		deg_to_rad(upper_turn_speed_degrees) * delta
	)

	var head_vector := opponent.global_position - head_aim_node.global_position
	head_aim_node.global_rotation = head_vector.angle() + PI * 0.5
	for aim_node in arm_aim_nodes:
		var arm_vector := opponent.global_position - aim_node.global_position
		aim_node.global_rotation = arm_vector.angle()


func _update_weapons(delta: float) -> void:
	for weapon in weapons:
		weapon.tick(delta)
	linked_fire_cooldown = maxf(linked_fire_cooldown - delta, 0.0)

	if reload_time_remaining > 0.0:
		reload_time_remaining = maxf(reload_time_remaining - delta, 0.0)
		if reload_time_remaining <= 0.0:
			for weapon in weapons:
				weapon.ammo = weapon.spec.ammo_capacity
		return

	if ammo_remaining() <= 0:
		reload_time_remaining = reload_duration
		return
	_try_fire_linked_group()


func _try_fire_linked_group() -> void:
	if linked_fire_cooldown > 0.0 or weapons.is_empty() or not is_instance_valid(opponent):
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

	var aim_vector := opponent.global_position - muzzle.global_position
	if aim_vector.length_squared() <= 1.0:
		aim_vector = muzzle.global_transform.x

	var spread_degrees := weapon.spec.spread_at_distance(aim_vector.length())
	var shot_seed := rng.randi()
	var spread_angle := deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees))
	var launch_direction := aim_vector.normalized().rotated(spread_angle)
	_spawn_projectile(weapon, muzzle.global_position, launch_direction, shot_seed, spread_degrees)
	_spawn_muzzle_flash(weapon.spec, muzzle.global_position, launch_direction)
	shot_count += 1


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
		self,
		weapon.part_name,
		shot_seed,
		spread_degrees
	)
	projectile_layer.add_child(projectile)
	projectile.global_position = spawn_position


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


func _build_mech() -> void:
	var body_map := AnchorMap.load_map(BODY_ANCHORS)
	var body_sprite := _create_sprite(BODY_ART, 3)
	body_sprite.name = "BodySprite"
	upper_body.add_child(body_sprite)

	var backpack_socket := AnchorMap.one(body_map, &"backpack_socket")
	_attach_static_part(upper_body, "Backpack", BACKPACK_ART, BACKPACK_ANCHORS, backpack_socket, 1)

	var legs_socket := AnchorMap.one(body_map, &"legs_socket")
	var legs := _attach_static_part(lower_body, "Legs", LEGS_ART, LEGS_ANCHORS, legs_socket, 2)
	_attach_boosts(legs)

	var head_socket := AnchorMap.one(body_map, &"head_socket")
	head_aim_node = _attach_rotating_head(upper_body, head_socket, 5)

	var left_arm_socket := AnchorMap.one(body_map, &"left_arm_socket")
	var left_arm := _attach_aiming_arm(upper_body, "LeftArm", left_arm_socket, 4)
	arm_aim_nodes.append(left_arm["aim"] as Node2D)
	weapons.append(left_arm["weapon"] as WeaponRuntime)

	var right_arm_socket := AnchorMap.one(body_map, &"right_arm_socket")
	var right_arm := _attach_aiming_arm(upper_body, "RightArm", right_arm_socket, 4)
	arm_aim_nodes.append(right_arm["aim"] as Node2D)
	weapons.append(right_arm["weapon"] as WeaponRuntime)


func _attach_static_part(
	parent: Node2D,
	part_name: String,
	art_path: String,
	anchor_path: String,
	socket_position: Vector2,
	z_index_value: int
) -> Dictionary:
	var anchor_map := AnchorMap.load_map(anchor_path)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var part_root := Node2D.new()
	part_root.name = part_name
	part_root.position = socket_position
	parent.add_child(part_root)

	var sprite := _create_sprite(art_path, z_index_value)
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
	z_index_value: int
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

	var sprite := _create_sprite(ARM_ART, z_index_value)
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


func _attach_rotating_head(parent: Node2D, socket_position: Vector2, z_index_value: int) -> Node2D:
	var anchor_map := AnchorMap.load_map(HEAD_ANCHORS)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_node := Node2D.new()
	aim_node.name = "HeadAimPivot"
	aim_node.position = socket_position
	parent.add_child(aim_node)

	var sprite := _create_sprite(HEAD_ART, z_index_value)
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
		var boost := AnimatedSprite2D.new()
		boost.name = "Boost%d" % (index + 1)
		boost.sprite_frames = frames
		boost.animation = &"burn"
		boost.position = boost_anchors[index] - legs_mount + Vector2(0, 2.5)
		boost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		boost.z_index = 1
		legs_root.add_child(boost)
		boost.play()
		boost_sprites.append(boost)


func _update_boost_effect() -> void:
	for boost in boost_sprites:
		boost.visible = velocity.length_squared() > 4.0


func _create_sprite(texture_path: String, z_index_value: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index_value
	return sprite
