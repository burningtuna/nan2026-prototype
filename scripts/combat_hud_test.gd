extends Control

const SIDEBAR_RATIO := 0.3
const SIDEBAR_MIN_WIDTH := 136.0
const SIDEBAR_MAX_WIDTH := 192.0

@onready var sidebar: PanelContainer = $Sidebar
@onready var hud: GameHud = $Sidebar/HudStack/GameHud
@onready var combat_container: SubViewportContainer = $CombatContainer
@onready var battle = $CombatContainer/CombatViewport/SampleAssembly
@onready var overlay: CombatOverlay = $CombatContainer/CombatViewport/OverlayLayer/CombatOverlay


func _ready() -> void:
	resized.connect(_update_layout)
	_update_layout()
	call_deferred("_bind_combat")


func _update_layout() -> void:
	var sidebar_width := clampf(size.x * SIDEBAR_RATIO, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
	sidebar.offset_right = sidebar_width
	combat_container.offset_left = sidebar_width + 1.0


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
