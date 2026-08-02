class_name PartDestructionEffect
extends Node2D

const LIFETIME := 1.15

var remaining := LIFETIME
var particles: Array[Dictionary] = []


func setup(random_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for index in 18:
		var direction := Vector2.from_angle(rng.randf_range(-PI, PI))
		particles.append({
			"kind": &"debris",
			"position": direction * rng.randf_range(0.0, 2.0),
			"velocity": direction * rng.randf_range(28.0, 72.0),
			"rotation": rng.randf_range(-PI, PI),
			"angular_velocity": rng.randf_range(-14.0, 14.0),
			"size": rng.randf_range(1.2, 2.8),
			"color": Color("ff9d32") if index % 3 == 0 else Color("273238"),
		})
	for index in 14:
		var direction := Vector2.from_angle(rng.randf_range(-PI, PI))
		particles.append({
			"kind": &"spark",
			"position": Vector2.ZERO,
			"velocity": direction * rng.randf_range(65.0, 125.0),
			"rotation": 0.0,
			"angular_velocity": 0.0,
			"size": rng.randf_range(2.0, 4.0),
			"color": Color("ffd765"),
		})
	for index in 10:
		var direction := Vector2.from_angle(rng.randf_range(-PI, PI))
		particles.append({
			"kind": &"smoke",
			"position": direction * rng.randf_range(1.0, 4.0),
			"velocity": direction * rng.randf_range(6.0, 20.0) + Vector2(0.0, -8.0),
			"rotation": 0.0,
			"angular_velocity": 0.0,
			"size": rng.randf_range(2.5, 5.0),
			"color": Color(0.28, 0.33, 0.35, rng.randf_range(0.35, 0.6)),
		})


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	for index in particles.size():
		var particle: Dictionary = particles[index]
		particle["position"] = particle["position"] + particle["velocity"] * delta
		if particle["kind"] == &"debris":
			particle["velocity"] = particle["velocity"] + Vector2(0.0, 42.0) * delta
		else:
			particle["velocity"] = particle["velocity"] * maxf(1.0 - delta * 2.5, 0.0)
		particle["rotation"] = particle["rotation"] + particle["angular_velocity"] * delta
		particles[index] = particle
	queue_redraw()


func _draw() -> void:
	var life_ratio := clampf(remaining / LIFETIME, 0.0, 1.0)
	var age_ratio := 1.0 - life_ratio
	if age_ratio < 0.16:
		var flash_ratio := 1.0 - age_ratio / 0.16
		draw_circle(Vector2.ZERO, 7.0 * flash_ratio, Color(1.0, 0.82, 0.38, flash_ratio))
		draw_circle(Vector2.ZERO, 12.0 * flash_ratio, Color(1.0, 0.32, 0.08, flash_ratio * 0.45))

	for particle in particles:
		var kind: StringName = particle["kind"]
		var position_value: Vector2 = particle["position"]
		var color: Color = particle["color"]
		if kind == &"smoke":
			color.a *= life_ratio
			var radius: float = particle["size"] * lerpf(0.7, 2.2, age_ratio)
			draw_circle(position_value, radius, color)
		elif kind == &"spark":
			color.a *= clampf(life_ratio * 2.0, 0.0, 1.0)
			var velocity: Vector2 = particle["velocity"]
			var trail: Vector2 = velocity.normalized() * float(particle["size"])
			draw_line(position_value, position_value - trail, color, 0.8)
		else:
			color.a *= life_ratio
			var size: float = particle["size"] * lerpf(0.45, 1.0, life_ratio)
			var rotation_value: float = particle["rotation"]
			var triangle := PackedVector2Array([
				Vector2(size, 0.0).rotated(rotation_value) + position_value,
				Vector2(-size * 0.7, size * 0.55).rotated(rotation_value) + position_value,
				Vector2(-size * 0.7, -size * 0.55).rotated(rotation_value) + position_value,
			])
			draw_colored_polygon(triangle, color)
