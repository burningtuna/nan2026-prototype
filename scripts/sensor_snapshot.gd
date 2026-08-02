class_name SensorSnapshot
extends RefCounted

var sequence := 0
var units: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []


func clear(next_sequence: int) -> void:
	sequence = next_sequence
	units.clear()
	projectiles.clear()


func unit_contact(target: Node) -> Dictionary:
	for contact in units:
		var contact_target = contact.get("target")
		if not is_instance_valid(contact_target):
			continue
		if contact_target == target:
			return contact
	return {}


func has_unit(target: Node) -> bool:
	return not unit_contact(target).is_empty()


func tracked_projectiles() -> Array[BallisticProjectile]:
	var result: Array[BallisticProjectile] = []
	for contact in projectiles:
		var projectile_value = contact.get("projectile")
		if not is_instance_valid(projectile_value):
			continue
		var projectile := projectile_value as BallisticProjectile
		if projectile != null:
			result.append(projectile)
	return result
