class_name MechPartSpec
extends Resource

enum PartType {
	HEAD,
	BODY,
	ARM_EQUIPMENT,
	BACKPACK,
	LEGS,
}

@export var display_name := "Unnamed Part"
@export var part_id := ""
@export var designation := "--"
@export_multiline var description := ""
@export var part_type := PartType.BODY
@export_file("*.png") var art_path := ""
@export_file("*.png") var anchor_path := ""
@export_file("*.png") var splash_art_path := ""
@export_file("*.png") var wireframe_art_path := ""
@export_file("*.png") var wireframe_anchor_path := ""
@export var preview_tint := Color.WHITE
@export var weapon: WeaponSpec
@export var armor := 0.0
@export var weight := 0.0
@export var power_generation := 0.0
@export var power_draw := 0.0
@export var cooling := 0.0
@export var mobility := 0.0
@export var firepower := 0.0
@export var weight_capacity := 0.0


func provides_weapon() -> bool:
	return weapon != null
