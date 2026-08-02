class_name VaporEffect
extends Node2D

const LIFETIME := 0.75
const VAPOR_COLOR := Color(0.72, 0.92, 1.0, 0.42)

var elapsed := 0.0
var velocity := Vector2.ZERO
var vapor_scale := 1.0


func setup(
	projectile_spec: ProjectileSpec,
	firing_direction: Vector2,
	random_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var direction := firing_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.rotated(deg_to_rad(rng.randf_range(-30.0, 30.0)))
	velocity = direction * rng.randf_range(5.0, 9.0)
	vapor_scale = maxf(projectile_spec.visual_scale, 0.5)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 10.0 * delta)
	queue_redraw()


func _draw() -> void:
	var progress := elapsed / LIFETIME
	var alpha := (1.0 - progress) * VAPOR_COLOR.a
	var spread := lerpf(1.0, 4.0, progress) * vapor_scale
	draw_circle(Vector2(-spread * 0.35, 0.0), spread * 0.55, Color(VAPOR_COLOR, alpha))
	draw_circle(Vector2(spread * 0.3, -spread * 0.2), spread * 0.4, Color(VAPOR_COLOR, alpha * 0.8))
	draw_circle(Vector2(spread * 0.1, spread * 0.35), spread * 0.3, Color.WHITE * Color(1.0, 1.0, 1.0, alpha * 0.55))
