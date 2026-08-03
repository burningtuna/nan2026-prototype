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
var combat_player: AiMechAgent
var player_hud_visible := true


func _ready() -> void:
	resized.connect(_update_layout)
	get_window().size_changed.connect(_update_layout)
	_update_layout()
	call_deferred("_update_layout")
	call_deferred("_bind_combat")


func _process(_delta: float) -> void:
	if not is_instance_valid(combat_player):
		return
	_set_player_hud_visible(not combat_player.is_defeated())
	overlay.set_target_focus(
		battle.target_camera_active,
		battle.focused_camera_target()
	)


func _update_layout() -> void:
	var target_sidebar_width := (
		clampf(size.x * SIDEBAR_RATIO, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
		if player_hud_visible
		else 0.0
	)
	var hud_scale := 0.0
	if player_hud_visible:
		hud_scale = minf(
			target_sidebar_width / HUD_DESIGN_SIZE.x,
			size.y / HUD_DESIGN_SIZE.y
		)
	var sidebar_width := HUD_DESIGN_SIZE.x * hud_scale
	sidebar.offset_right = sidebar_width
	hud_canvas.scale = Vector2.ONE * hud_scale
	var combat_position := Vector2(sidebar_width + (1.0 if player_hud_visible else 0.0), 0.0)
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
	combat_player = player
	var allies := [battle.agents[1]]
	var enemies := [battle.agents[2], battle.agents[3]]
	battle.get_node("UI").visible = false
	hud.bind(player, allies, enemies, battle.projectile_layer)
	overlay.bind(player, allies, enemies, battle.projectile_layer)
	battle.battle_finished.connect(_on_battle_finished)
	if battle.battle_completed:
		_on_battle_finished(battle.winner_team_id)
	if OS.get_cmdline_user_args().has("--hud-spectator-smoke"):
		call_deferred("_run_hud_spectator_smoke")
	if OS.get_cmdline_user_args().has("--targeting-solution-smoke"):
		call_deferred("_run_targeting_solution_smoke")


func _set_player_hud_visible(value: bool) -> void:
	if player_hud_visible == value:
		return
	player_hud_visible = value
	sidebar.visible = value
	hud_canvas.visible = value
	overlay.set_combat_hud_visible(value)
	_update_layout()


func _run_hud_spectator_smoke() -> void:
	combat_player.register_hit(
		&"Body",
		Vector2.RIGHT,
		float(combat_player.part_durability[&"Body"])
	)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(combat_player.is_defeated())
	assert(not player_hud_visible)
	assert(not sidebar.visible)
	assert(combat_container.position.x == 0.0)
	assert(not overlay.combat_hud_visible)
	assert(not overlay.target_preview.visible)
	print("COMBAT_HUD_SPECTATOR_CHECK passed")
	get_tree().quit(0)


func _run_targeting_solution_smoke() -> void:
	var target := battle.agents[2] as AiMechAgent
	combat_player.sensor_snapshot.units.assign([{
		"target": target,
		"position": target.global_position,
		"velocity": Vector2(80.0, 20.0),
		"preparing": false,
		"dashing": false,
		"durability": target._part_durability_snapshot(),
	}])
	combat_player.selected_sensor_target = target
	combat_player.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_ALL
	overlay.set_target_focus(true, target)
	var weapon := overlay._targeting_weapon()
	assert(weapon != null)
	var longest_range := 0.0
	for selected_weapon in combat_player.selected_weapons():
		longest_range = maxf(longest_range, selected_weapon.spec.max_range)
	assert(is_equal_approx(weapon.spec.max_range, longest_range))
	var lead := overlay._intercept_position(
		combat_player.global_position,
		target.global_position,
		Vector2(80.0, 20.0),
		weapon.spec.projectile.speed
	)
	assert(not lead.is_equal_approx(target.global_position))
	overlay._update_target_preview()
	assert(overlay.displayed_target == target)
	print("TARGETING_SOLUTION_CHECK passed")
	get_tree().quit(0)


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
