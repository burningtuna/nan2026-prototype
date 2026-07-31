class_name BallisticProjectile
extends Area2D

var spec: ProjectileSpec
var direction := Vector2.RIGHT
var max_distance := 0.0
var traveled_distance := 0.0
var source_mech: Node
var source_part: StringName
var shot_seed := 0
var launch_spread_degrees := 0.0


func configure(
	projectile_spec: ProjectileSpec,
	launch_direction: Vector2,
	travel_limit: float,
	shot_source: Node,
	part_name: StringName,
	seed: int,
	spread_degrees: float
) -> void:
	spec = projectile_spec
	direction = launch_direction.normalized()
	max_distance = travel_limit
	source_mech = shot_source
	source_part = part_name
	shot_seed = seed
	launch_spread_degrees = spread_degrees
	rotation = direction.angle()


func _ready() -> void:
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = spec.collision_radius
	collision_shape.shape = circle
	add_child(collision_shape)
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	var remaining_distance := maxf(max_distance - traveled_distance, 0.0)
	var frame_distance := minf(spec.speed * delta, remaining_distance)
	global_position += direction * frame_distance
	traveled_distance += frame_distance
	if traveled_distance >= max_distance:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-2.0, -0.5, 4.0, 1.0), spec.color)
	draw_circle(Vector2(1.5, 0.0), 1.0, Color.WHITE)
