class_name ImpactEffect
extends Node2D

var weapon_family := WeaponSpec.WeaponFamily.BALLISTIC
var lifetime := 0.28
var remaining := 0.28
var particles: Array[Dictionary] = []


func setup(family: WeaponSpec.WeaponFamily, incoming_direction: Vector2, random_seed: int) -> void:
	weapon_family = family
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE:
		lifetime = 0.5
		remaining = lifetime
		_build_smoke(rng)
	else:
		_build_fragments(rng, incoming_direction)


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return

	for index in particles.size():
		var particle: Dictionary = particles[index]
		particle["position"] = particle["position"] + particle["velocity"] * delta
		particle["velocity"] = particle["velocity"] * maxf(1.0 - delta * 3.0, 0.0)
		particle["rotation"] = particle["rotation"] + particle["angular_velocity"] * delta
		particles[index] = particle
	queue_redraw()


func _draw() -> void:
	var life_ratio := clampf(remaining / lifetime, 0.0, 1.0)
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE:
		_draw_smoke(life_ratio)
	else:
		_draw_fragments(life_ratio)


func _build_fragments(rng: RandomNumberGenerator, incoming_direction: Vector2) -> void:
	var colors := [Color("151515"), Color("ffd34d")]
	if weapon_family == WeaponSpec.WeaponFamily.ENERGY:
		colors = [Color.WHITE, Color("55cfff")]
	var rebound_angle := (-incoming_direction).angle()
	for index in 8:
		var direction := Vector2.from_angle(rebound_angle + rng.randf_range(-1.25, 1.25))
		particles.append({
			"position": Vector2.ZERO,
			"velocity": direction * rng.randf_range(18.0, 46.0),
			"rotation": rng.randf_range(-PI, PI),
			"angular_velocity": rng.randf_range(-12.0, 12.0),
			"size": rng.randf_range(1.5, 2.8),
			"color": colors[index % colors.size()],
		})


func _build_smoke(rng: RandomNumberGenerator) -> void:
	for index in 9:
		var direction := Vector2.from_angle(rng.randf_range(-PI, PI))
		particles.append({
			"position": direction * rng.randf_range(0.0, 3.0),
			"velocity": direction * rng.randf_range(5.0, 18.0),
			"rotation": 0.0,
			"angular_velocity": 0.0,
			"size": rng.randf_range(2.0, 4.0),
			"color": Color(0.72, 0.75, 0.78, rng.randf_range(0.25, 0.5)),
		})


func _draw_fragments(life_ratio: float) -> void:
	for particle in particles:
		var size: float = particle["size"] * lerpf(0.35, 1.0, life_ratio)
		var rotation_value: float = particle["rotation"]
		var position_value: Vector2 = particle["position"]
		var color: Color = particle["color"]
		color.a *= life_ratio
		var triangle := PackedVector2Array([
			Vector2(size, 0.0).rotated(rotation_value) + position_value,
			Vector2(-size * 0.65, size * 0.55).rotated(rotation_value) + position_value,
			Vector2(-size * 0.65, -size * 0.55).rotated(rotation_value) + position_value,
		])
		draw_colored_polygon(triangle, color)


func _draw_smoke(life_ratio: float) -> void:
	var age_ratio := 1.0 - life_ratio
	for particle in particles:
		var color: Color = particle["color"]
		color.a *= life_ratio
		var radius: float = particle["size"] * lerpf(0.7, 1.8, age_ratio)
		draw_circle(particle["position"], radius, color)
	draw_circle(Vector2.ZERO, 4.0 * life_ratio, Color(1.0, 0.72, 0.16, life_ratio * 0.8))
