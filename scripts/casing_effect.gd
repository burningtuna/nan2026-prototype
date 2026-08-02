class_name CasingEffect
extends Node2D

const LIFETIME := 1.0
const CASING_COLOR := Color("d8a657")
const CASING_HIGHLIGHT := Color("f6d77a")
const SHADOW_COLOR := Color(0.01, 0.02, 0.025, 0.38)
const INITIAL_SHADOW_OFFSET := Vector2(2.5, 5.0)

var elapsed := 0.0
var velocity := Vector2.ZERO
var casing_size := Vector2.ONE
var shadow_offset := INITIAL_SHADOW_OFFSET


func setup(
	projectile_spec: ProjectileSpec,
	projectile_count: int,
	firing_direction: Vector2,
	random_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var direction := firing_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.rotated(deg_to_rad(rng.randf_range(-30.0, 30.0)))
	velocity = direction * rng.randf_range(12.0, 18.0)
	rotation = direction.angle()

	var visual_scale := maxf(projectile_spec.visual_scale, 0.1)
	var thickness_multiplier := 1.0
	if projectile_count > 1:
		thickness_multiplier = float(projectile_count) / 3.0
	casing_size = Vector2(
		maxf(visual_scale * 2.0, 1.0),
		maxf(visual_scale * thickness_multiplier, 1.0)
	)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 18.0 * delta)
	var progress := elapsed / LIFETIME
	shadow_offset = INITIAL_SHADOW_OFFSET.lerp(Vector2.ZERO, progress)
	modulate.a = clampf((1.0 - progress) * 4.0, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var casing_rect := Rect2(-casing_size * 0.5, casing_size)
	draw_set_transform(shadow_offset)
	draw_rect(casing_rect, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
	draw_rect(casing_rect, CASING_COLOR)
	draw_line(
		Vector2(-casing_size.x * 0.3, -casing_size.y * 0.25),
		Vector2(casing_size.x * 0.3, -casing_size.y * 0.25),
		CASING_HIGHLIGHT,
		1.0
	)
