extends Control

const SIDEBAR_RATIO := 0.3
const SIDEBAR_MIN_WIDTH := 136.0
const SIDEBAR_MAX_WIDTH := 192.0
const HUD_DESIGN_SIZE := Vector2(144.0, 270.0)
const HANGAR_SCENE_PATH := "res://scenes/hangar_screen.tscn"
const RESULT_DISPLAY_SECONDS := 2.5

@onready var sidebar: PanelContainer = $Sidebar
@onready var hud_canvas: Control = $Sidebar/HudStack/HudCanvas
@onready var hud: GameHud = $Sidebar/HudStack/HudCanvas/GameHud
@onready var combat_container: SubViewportContainer = $CombatContainer
@onready var combat_viewport: SubViewport = $CombatContainer/CombatViewport
@onready var battle = $CombatContainer/CombatViewport/SampleAssembly
@onready var overlay: CombatOverlay = $CombatContainer/CombatViewport/OverlayLayer/CombatOverlay

var returning_to_hangar := false


func _ready() -> void:
	resized.connect(_update_layout)
	get_window().size_changed.connect(_update_layout)
	_update_layout()
	call_deferred("_update_layout")
	call_deferred("_bind_combat")


func _update_layout() -> void:
	var target_sidebar_width := clampf(size.x * SIDEBAR_RATIO, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
	var hud_scale := minf(
		target_sidebar_width / HUD_DESIGN_SIZE.x,
		size.y / HUD_DESIGN_SIZE.y
	)
	var sidebar_width := HUD_DESIGN_SIZE.x * hud_scale
	sidebar.offset_right = sidebar_width
	hud_canvas.scale = Vector2.ONE * hud_scale
	var combat_position := Vector2(sidebar_width + 1.0, 0.0)
	var logical_combat_size := Vector2(
		maxf(size.x - combat_position.x, 1.0),
		maxf(size.y, 1.0)
	)
	var render_scale := _screen_render_scale()
	var render_size := Vector2i(
		maxi(roundi(logical_combat_size.x * render_scale.x), 1),
		maxi(roundi(logical_combat_size.y * render_scale.y), 1)
	)

	combat_container.position = combat_position
	combat_container.size = Vector2(render_size)
	combat_container.scale = Vector2(1.0 / render_scale.x, 1.0 / render_scale.y)
	combat_viewport.size = render_size
	combat_viewport.size_2d_override = Vector2i(
		maxi(roundi(logical_combat_size.x), 1),
		maxi(roundi(logical_combat_size.y), 1)
	)
	combat_viewport.size_2d_override_stretch = true


func _screen_render_scale() -> Vector2:
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	return Vector2(
		maxf(window_size.x / size.x, 0.25),
		maxf(window_size.y / size.y, 0.25)
	)


func _bind_combat() -> void:
	if battle.agents.size() < 4:
		push_error("Combat HUD requires a player, ally, and two enemies")
		return
	var player := battle.agents[0] as AiMechAgent
	var allies := [battle.agents[1]]
	var enemies := [battle.agents[2], battle.agents[3]]
	battle.get_node("UI").visible = false
	hud.bind(player, allies, enemies, battle.projectile_layer)
	overlay.bind(player, allies, enemies, battle.projectile_layer)
	battle.battle_finished.connect(_on_battle_finished)
	if battle.battle_completed:
		_on_battle_finished(battle.winner_team_id)


func _on_battle_finished(winner_team_id: int) -> void:
	overlay.show_team_victory(winner_team_id + 1)
	if returning_to_hangar:
		return
	returning_to_hangar = true
	_return_to_hangar()


func _return_to_hangar() -> void:
	await get_tree().create_timer(RESULT_DISPLAY_SECONDS).timeout
	var error := get_tree().change_scene_to_file(HANGAR_SCENE_PATH)
	if error != OK:
		returning_to_hangar = false
		push_error("Unable to return to hangar: %s" % error_string(error))
