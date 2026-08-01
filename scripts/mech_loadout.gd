class_name MechLoadout
extends Resource

enum MechSlot {
	HEAD,
	BODY,
	LEFT_ARM,
	RIGHT_ARM,
	BACKPACK,
	LEGS,
}

@export var head: MechPartSpec
@export var body: MechPartSpec
@export var left_arm: MechPartSpec
@export var right_arm: MechPartSpec
@export var backpack: MechPartSpec
@export var legs: MechPartSpec


func copy() -> MechLoadout:
	var result := MechLoadout.new()
	result.head = head
	result.body = body
	result.left_arm = left_arm
	result.right_arm = right_arm
	result.backpack = backpack
	result.legs = legs
	return result


func part_for_slot(slot: MechSlot) -> MechPartSpec:
	match slot:
		MechSlot.HEAD:
			return head
		MechSlot.BODY:
			return body
		MechSlot.LEFT_ARM:
			return left_arm
		MechSlot.RIGHT_ARM:
			return right_arm
		MechSlot.BACKPACK:
			return backpack
		MechSlot.LEGS:
			return legs
	return null


func set_part(slot: MechSlot, part: MechPartSpec) -> void:
	match slot:
		MechSlot.HEAD:
			head = part
		MechSlot.BODY:
			body = part
		MechSlot.LEFT_ARM:
			left_arm = part
		MechSlot.RIGHT_ARM:
			right_arm = part
		MechSlot.BACKPACK:
			backpack = part
		MechSlot.LEGS:
			legs = part


func equipped_parts() -> Array[MechPartSpec]:
	var parts: Array[MechPartSpec] = []
	for part in [head, body, left_arm, right_arm, backpack, legs]:
		if part != null:
			parts.append(part)
	return parts


func stats() -> Dictionary:
	var totals := {
		"armor": 0.0,
		"weight": 0.0,
		"power_generation": 0.0,
		"power_draw": 0.0,
		"cooling": 0.0,
		"mobility": 0.0,
		"firepower": 0.0,
		"weight_capacity": 0.0,
	}
	for part in equipped_parts():
		totals["armor"] += part.armor
		totals["weight"] += part.weight
		totals["power_generation"] += part.power_generation
		totals["power_draw"] += part.power_draw
		totals["cooling"] += part.cooling
		totals["mobility"] += part.mobility
		totals["firepower"] += part.firepower
		totals["weight_capacity"] += part.weight_capacity
	return totals


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if body == null:
		errors.append("BODY PART REQUIRED")
	if head == null:
		errors.append("HEAD PART REQUIRED")
	if legs == null:
		errors.append("LEGS PART REQUIRED")
	if not has_weapon():
		errors.append("EQUIP AT LEAST ONE WEAPON")

	var totals := stats()
	var capacity: float = totals["weight_capacity"]
	if capacity > 0.0 and totals["weight"] > capacity:
		errors.append("WEIGHT LIMIT EXCEEDED")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func has_weapon() -> bool:
	for part in equipped_parts():
		if part.provides_weapon():
			return true
	return false
