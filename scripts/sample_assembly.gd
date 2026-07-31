extends Node2D

const AnchorMap := preload("res://scripts/sprite_anchor_map.gd")

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

@onready var mech: Node2D = $Mech
@onready var status_label: Label = $UI/Status

var arm_aim_nodes: Array[Node2D] = []
var head_aim_node: Node2D
var boost_sprites: Array[AnimatedSprite2D] = []
var boost_enabled := true
var mouse_aim_active := false


func _ready() -> void:
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_aim_active = true

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			boost_enabled = not boost_enabled
			for boost_sprite in boost_sprites:
				boost_sprite.visible = boost_enabled
			_update_status()


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
	mech.add_child(body_sprite)

	var backpack_socket := AnchorMap.one(body_map, &"backpack_socket")
	_attach_static_part("Backpack", BACKPACK_ART, BACKPACK_ANCHORS, backpack_socket, -2)

	var legs_socket := AnchorMap.one(body_map, &"legs_socket")
	var legs := _attach_static_part("Legs", LEGS_ART, LEGS_ANCHORS, legs_socket, -1)
	_attach_boosts(legs)

	var head_socket := AnchorMap.one(body_map, &"head_socket")
	head_aim_node = _attach_rotating_head(head_socket, 4)

	var left_arm_socket := AnchorMap.one(body_map, &"left_arm_socket")
	arm_aim_nodes.append(_attach_aiming_arm("LeftArm", left_arm_socket, 3))

	var right_arm_socket := AnchorMap.one(body_map, &"right_arm_socket")
	arm_aim_nodes.append(_attach_aiming_arm("RightArm", right_arm_socket, 3))


func _attach_static_part(
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
	mech.add_child(part_root)

	var sprite := _create_sprite(art_path, z_index)
	sprite.name = "%sSprite" % part_name
	sprite.position = -mount
	part_root.add_child(sprite)

	return {
		"root": part_root,
		"map": anchor_map,
		"mount": mount,
	}


func _attach_aiming_arm(part_name: String, socket_position: Vector2, z_index: int) -> Node2D:
	var anchor_map := AnchorMap.load_map(ARM_ANCHORS)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_pivot := AnchorMap.one(anchor_map, &"aim_pivot")

	var mount_root := Node2D.new()
	mount_root.name = "%sMount" % part_name
	mount_root.position = socket_position
	mech.add_child(mount_root)

	var aim_node := Node2D.new()
	aim_node.name = "%sAimPivot" % part_name
	aim_node.position = aim_pivot - mount
	aim_node.rotation = -PI * 0.5
	mount_root.add_child(aim_node)

	var sprite := _create_sprite(ARM_ART, z_index)
	sprite.name = "%sSprite" % part_name
	sprite.position = -aim_pivot
	aim_node.add_child(sprite)

	var muzzle := Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = AnchorMap.one(anchor_map, &"muzzle") - aim_pivot
	aim_node.add_child(muzzle)

	return aim_node


func _attach_rotating_head(socket_position: Vector2, z_index: int) -> Node2D:
	var anchor_map := AnchorMap.load_map(HEAD_ANCHORS)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_node := Node2D.new()
	aim_node.name = "HeadAimPivot"
	aim_node.position = socket_position
	mech.add_child(aim_node)

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
		legs_root.add_child(boost)
		boost.play()
		boost_sprites.append(boost)


func _create_sprite(texture_path: String, z_index: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index
	return sprite


func _center_mech() -> void:
	mech.position = get_viewport_rect().size * 0.5


func _update_status() -> void:
	status_label.text = "ANCHOR ASSEMBLY: OK    BOOST: %s" % ("ON" if boost_enabled else "OFF")
