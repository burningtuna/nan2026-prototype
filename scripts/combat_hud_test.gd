extends Control

const SIDEBAR_RATIO := 0.3
const SIDEBAR_MIN_WIDTH := 136.0
const SIDEBAR_MAX_WIDTH := 192.0

@onready var sidebar: PanelContainer = $Sidebar
@onready var hud: GameHud = $Sidebar/HudStack/GameHud
@onready var combat_container: SubViewportContainer = $CombatContainer
@onready var combat_viewport: SubViewport = $CombatContainer/CombatViewport
@onready var battle = $CombatContainer/CombatViewport/SampleAssembly
@onready var overlay: CombatOverlay = $CombatContainer/CombatViewport/OverlayLayer/CombatOverlay


func _ready() -> void:
	resized.connect(_update_layout)
	get_window().size_changed.connect(_update_layout)
	_update_layout()
	call_deferred("_update_layout")
	call_deferred("_bind_combat")


func _update_layout() -> void:
	var sidebar_width := clampf(size.x * SIDEBAR_RATIO, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
	sidebar.offset_right = sidebar_width
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
	overlay.bind(player, enemies, battle.projectile_layer)
