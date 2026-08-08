extends Control

const BG := Color("071014")
const PANEL := Color("0d1b20")
const PANEL_ALT := Color("11252a")
const LINE := Color("24424a")
const TEXT := Color("d7e1df")
const MUTED := Color("718b8e")
const CYAN := Color("5ce1d0")
const AMBER := Color("f5bd55")
const RED := Color("e05a55")
const NEWS_GREEN := Color("62ed8c")
const NEWS_DISPLAY_SECONDS := 5.0
const PARTS_DATA_PATH := "res://data/mech_parts.json"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SKIRMISH_SCENE_PATH := "res://scenes/combat_hud_test.tscn"
const ENDLESS_SCENE_PATH := "res://scenes/endless_combat.tscn"
const STORY_STAGE_SELECT_PATH := "res://scenes/story_stage_select.tscn"
const STAGE_02_PATH := "res://scenes/stage_02.tscn"
const STAGE_03_PATH := "res://scenes/stage_03.tscn"
const ENDLESS_INTRO_PATH := "res://data/scenarios/endless_intro.json"
const STAGE_02_HANGAR_DIALOGUE_PATH := "res://data/scenarios/stage_02_hangar.json"
const STAGE_03_HANGAR_DIALOGUE_PATH := "res://data/scenarios/stage_03_hangar.json"
const STAGE_04_HANGAR_DIALOGUE_PATH := "res://data/scenarios/stage_04_hangar.json"
const STAGE_05_HANGAR_DIALOGUE_PATH := "res://data/scenarios/stage_05_hangar.json"
const SCENARIO_DIALOGUE_SCENE := preload("res://scenes/scenario_dialogue.tscn")
const STORY_NEWS_HEADLINES := {
	"res://scenes/stage_02.tscn": "국경 지역에서 원인 불명의 대규모 폭발 발생",
	"res://scenes/stage_03.tscn": "국경 사태 악화, 정부가 예비군 동원 절차에 착수",
}

const SLOT_NAMES := {
	MechLoadout.MechSlot.BODY: "BODY",
	MechLoadout.MechSlot.HEAD: "HEAD",
	MechLoadout.MechSlot.LEFT_ARM: "LEFT ARM",
	MechLoadout.MechSlot.RIGHT_ARM: "RIGHT ARM",
	MechLoadout.MechSlot.BACKPACK: "BACKPACK",
	MechLoadout.MechSlot.LEGS: "LEGS",
}
const SLOT_ORDER := [
	MechLoadout.MechSlot.BODY,
	MechLoadout.MechSlot.HEAD,
	MechLoadout.MechSlot.LEFT_ARM,
	MechLoadout.MechSlot.RIGHT_ARM,
	MechLoadout.MechSlot.BACKPACK,
	MechLoadout.MechSlot.LEGS,
]
const STAGE_02_ALLOWED_PART_IDS := {
	MechLoadout.MechSlot.BODY: ["kestrel_core"],
	MechLoadout.MechSlot.HEAD: ["falcon_sensor"],
	MechLoadout.MechSlot.LEFT_ARM: ["rx_autocannon", "tempest_rocket", "arc_pulse"],
	MechLoadout.MechSlot.RIGHT_ARM: ["rx_autocannon", "tempest_rocket", "arc_pulse"],
	MechLoadout.MechSlot.BACKPACK: ["grid_generator", "heat_sink_array"],
	MechLoadout.MechSlot.LEGS: ["strider_legs"],
}
const STAGE_02_FALLBACK_PART_IDS := {
	MechLoadout.MechSlot.BODY: "kestrel_core",
	MechLoadout.MechSlot.HEAD: "falcon_sensor",
	MechLoadout.MechSlot.LEFT_ARM: "rx_autocannon",
	MechLoadout.MechSlot.RIGHT_ARM: "rx_autocannon",
	MechLoadout.MechSlot.BACKPACK: "grid_generator",
	MechLoadout.MechSlot.LEGS: "strider_legs",
}
const STAGE_03_ALLOWED_PART_DESIGNATIONS := {
	MechLoadout.MechSlot.BODY: ["BD-00", "BD-01"],
	MechLoadout.MechSlot.HEAD: ["HD-01", "HD-02"],
	MechLoadout.MechSlot.LEFT_ARM: [
		"AR-11", "AR-15", "AR-22", "AR-31", "AR-B01", "AR-B02", "AR-E01", "AR-E02", "AR-M01",
	],
	MechLoadout.MechSlot.RIGHT_ARM: [
		"AR-11", "AR-15", "AR-22", "AR-31", "AR-B01", "AR-B02", "AR-E01", "AR-E02", "AR-M01",
	],
	MechLoadout.MechSlot.BACKPACK: ["BP-05", "BP-09"],
	MechLoadout.MechSlot.LEGS: ["LG-01", "LG-03"],
}

@onready var mech_preview: MechWireframePreview = $MechPreview

var _catalog: Dictionary = {}
var _part_catalog: MechPartCatalog
var _working_loadout: MechLoadout
var _slot_buttons: Dictionary = {}
var _stat_bars: Dictionary = {}
var _status_label: Label
var _validation_label: Label
var _confirm_button: Button
var _main_menu_button: Button
var _overlay: Control
var _overlay_title: Label
var _candidate_list: VBoxContainer
var _candidate_parts: Dictionary = {}
var _detail_name: Label
var _detail_kind: Label
var _detail_description: Label
var _detail_stats: Label
var _detail_weapon: Label
var _equip_button: Button
var _pending_part: MechPartSpec
var _active_slot := MechLoadout.MechSlot.BODY
var _confirmed := false
var _scenario_dialogue: ScenarioDialogue
var _news_banner: PanelContainer
var _news_label: Label
var _news_timer: Timer


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--story-hangar-stage-02-smoke"):
		GameSession.selected_game_mode = GameSession.GameMode.STORY
		GameSession.story_deployment_scene_path = STAGE_02_PATH
	elif user_args.has("--story-hangar-stage-05-smoke"):
		GameSession.selected_game_mode = GameSession.GameMode.STORY
		GameSession.story_deployment_scene_path = "res://scenes/stage_05.tscn"
	elif user_args.has("--story-hangar-stage-04-smoke"):
		GameSession.selected_game_mode = GameSession.GameMode.STORY
		GameSession.story_deployment_scene_path = "res://scenes/stage_04.tscn"
	elif user_args.has("--story-hangar-smoke") or user_args.has("--story-deploy-smoke"):
		GameSession.selected_game_mode = GameSession.GameMode.STORY
		GameSession.story_deployment_scene_path = STAGE_03_PATH
	if not _build_catalog():
		return
	if user_args.has("--story-hangar-stage-02-smoke"):
		GameSession.player_mech_loadout = _part_catalog.create_default_loadout()
	_working_loadout = _initial_loadout()
	_build_interface()
	_build_news_banner()
	_refresh()
	_scenario_dialogue = SCENARIO_DIALOGUE_SCENE.instantiate() as ScenarioDialogue
	add_child(_scenario_dialogue)
	_scenario_dialogue.dialogue_finished.connect(_on_hangar_dialogue_finished)
	var dialogue_started := false
	if (
		GameSession.selected_game_mode == GameSession.GameMode.ENDLESS
		and not GameSession.endless_intro_shown
		and _scenario_dialogue.play_file(ENDLESS_INTRO_PATH)
	):
		dialogue_started = true
		GameSession.endless_intro_shown = true
	elif _is_stage_02_story_deployment():
		dialogue_started = _scenario_dialogue.play_file(STAGE_02_HANGAR_DIALOGUE_PATH)
	elif (
		GameSession.selected_game_mode == GameSession.GameMode.STORY
		and GameSession.story_deployment_scene_path == STAGE_03_PATH
	):
		dialogue_started = _scenario_dialogue.play_file(STAGE_03_HANGAR_DIALOGUE_PATH)
	elif (
		GameSession.selected_game_mode == GameSession.GameMode.STORY
		and GameSession.story_deployment_scene_path == "res://scenes/stage_04.tscn"
	):
		dialogue_started = _scenario_dialogue.play_file(STAGE_04_HANGAR_DIALOGUE_PATH)
	elif (
		GameSession.selected_game_mode == GameSession.GameMode.STORY
		and GameSession.story_deployment_scene_path == "res://scenes/stage_05.tscn"
	):
		dialogue_started = _scenario_dialogue.play_file(STAGE_05_HANGAR_DIALOGUE_PATH)
	if not dialogue_started:
		_show_story_news_headline()
	queue_redraw()
	if OS.get_cmdline_user_args().has("--scene-transition-smoke"):
		call_deferred("_confirm_loadout")
	if OS.get_cmdline_user_args().has("--endless-entry-smoke"):
		if SceneTransition.transitioning:
			SceneTransition.transition_finished.connect(
				func(_scene_path: String) -> void: _run_endless_hangar_entry_smoke(),
				CONNECT_ONE_SHOT
			)
		else:
			call_deferred("_run_endless_hangar_entry_smoke")
	if OS.get_cmdline_user_args().has("--hangar-main-menu-smoke"):
		call_deferred("_return_to_main_menu")
	if OS.get_cmdline_user_args().has("--hangar-return-smoke"):
		print("HANGAR_RETURN_CHECK passed")
		get_tree().quit(0)
	if OS.get_cmdline_user_args().has("--story-hangar-smoke"):
		call_deferred("_run_story_hangar_smoke")
	if user_args.has("--story-hangar-stage-02-smoke"):
		call_deferred("_run_story_hangar_stage_02_smoke")
	if user_args.has("--story-hangar-stage-04-smoke"):
		call_deferred("_run_story_hangar_stage_04_smoke")
	if user_args.has("--story-hangar-stage-05-smoke"):
		call_deferred("_run_story_hangar_stage_05_smoke")
	if OS.get_cmdline_user_args().has("--story-deploy-smoke"):
		call_deferred("_confirm_loadout")


func _run_endless_hangar_entry_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.ENDLESS)
	assert(_scenario_dialogue.active)
	assert(_scenario_dialogue.current_text() == "무한 모드입니다. 뱀파이어 서바이버 처럼 최대한 오래 살아남는게 목적입니다.")
	_scenario_dialogue.advance()
	assert(_scenario_dialogue.current_text() == "다른 모드와 별개의 장비 스탯을 사용합니다. 재장전 스트레스 없이 열, EN 관리가 목표가 됩니다.")
	_scenario_dialogue.advance()
	assert(_scenario_dialogue.current_text() == "전투 시간이 1분 증가할 때마다 플레이어가 받는 피해가 기본 배율 대비 5%씩 증가합니다.")
	_scenario_dialogue.advance()
	assert(_scenario_dialogue.current_text() == "발사 준비시간과 준비 중 이동 속도 감소가 제거됩니다. 최대 사거리 500 이상의 실탄 및 에너지 직선 공격은 적을 관통합니다.")
	_scenario_dialogue.advance()
	assert(not _scenario_dialogue.active)
	_confirm_loadout()


func _run_story_hangar_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
	assert(_deployment_scene_path() == STAGE_03_PATH)
	assert(_confirm_button.text == "DEPLOY STORY")
	assert(_loadout_matches_deployment_policy(_working_loadout))
	for slot in SLOT_ORDER:
		_open_part_picker(slot)
		var actual_designations: Array[String] = []
		for part_value in _candidate_parts.values():
			var part := part_value as MechPartSpec
			if part != null:
				actual_designations.append(part.designation)
		var expected_designations: Array[String] = []
		expected_designations.assign(STAGE_03_ALLOWED_PART_DESIGNATIONS[slot])
		actual_designations.sort()
		expected_designations.sort()
		assert(actual_designations == expected_designations)
	_close_part_picker()
	assert(_scenario_dialogue.current_speaker() == "오퍼레이터")
	assert(_scenario_dialogue.current_text() == "아레나의 보스에 도전할 기회를 얻었네 축하해.")
	assert(_scenario_dialogue.dialogue.size() == 4)
	for _index in _scenario_dialogue.dialogue.size():
		_scenario_dialogue.advance()
	assert(_news_banner.visible)
	assert(_news_label.text == "NEWS // 국경 사태 악화, 정부가 예비군 동원 절차에 착수")
	assert(is_equal_approx(_news_timer.wait_time, NEWS_DISPLAY_SECONDS))
	print("STORY_HANGAR_CHECK passed")
	get_tree().quit(0)


func _run_story_hangar_stage_02_smoke() -> void:
	assert(_is_stage_02_story_deployment())
	assert(_deployment_scene_path() == STAGE_02_PATH)
	assert(_loadout_matches_deployment_policy(_working_loadout))
	for slot in SLOT_ORDER:
		assert(_working_loadout.part_for_slot(slot).part_id == STAGE_02_FALLBACK_PART_IDS[slot])
		_open_part_picker(slot)
		var actual_ids: Array[String] = []
		for part_value in _candidate_parts.values():
			var part := part_value as MechPartSpec
			actual_ids.append(part.part_id if part != null else "")
		var expected_ids: Array[String] = []
		expected_ids.assign(STAGE_02_ALLOWED_PART_IDS[slot])
		if _is_optional(slot):
			expected_ids.append("")
		actual_ids.sort()
		expected_ids.sort()
		assert(actual_ids == expected_ids)
	_close_part_picker()
	assert(_scenario_dialogue.current_speaker() == "오퍼레이터")
	var expected_texts := [
		"여기는 출격 전에 사용 가능한 무장을 선택 가능한 격납고야.",
		"가장 중요한건 최소한 하나의 무장을 선택해야 한다는 것과, 다리가 허용 가능한 중량 내에서 조합을 해야 한다는 거지.",
		"기체가 무거워질수록 회피 거리가 짧아지고, 기동력이 줄어들수록 기동력과 회피 속도가 느려져서 미사일을 피하기가 어려워져.",
		"이제 원하는 대로 기체를 세트후 에 출격해.",
	]
	for expected_text in expected_texts:
		assert(_scenario_dialogue.current_text() == expected_text)
		_scenario_dialogue.advance()
	assert(not _scenario_dialogue.active)
	assert(_news_banner.visible)
	assert(_news_label.text == "NEWS // 국경 지역에서 원인 불명의 대규모 폭발 발생")
	assert(is_equal_approx(_news_timer.wait_time, NEWS_DISPLAY_SECONDS))
	_news_timer.timeout.emit()
	assert(not _news_banner.visible)
	print("STORY_HANGAR_STAGE_02_CHECK passed")
	get_tree().quit(0)


func _run_story_hangar_stage_04_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
	assert(_deployment_scene_path() == "res://scenes/stage_04.tscn")
	assert(_scenario_dialogue.current_speaker() == "오퍼레이터")
	assert(_scenario_dialogue.dialogue.size() == 4)
	var expected_texts := [
		"갑자기 징집되어서 싸우게 되다니..",
		"투기장이 아니라 진짜 전장으로 가게 되었군.",
		"이번에는 공격당한 도시로 배치가 되어서, 적의 지휘관 유닛을 파괴하는게 목표야.",
		"좁은 시가지기 때문에, 그걸 고려해서 무장을 선택해서 출격하는 것이 좋을거야.",
	]
	for expected_text in expected_texts:
		assert(_scenario_dialogue.current_text() == expected_text)
		_scenario_dialogue.advance()
	assert(not _scenario_dialogue.active)
	assert(not _news_banner.visible)
	print("STORY_HANGAR_STAGE_04_CHECK passed")
	get_tree().quit(0)


func _run_story_hangar_stage_05_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
	assert(_deployment_scene_path() == "res://scenes/stage_05.tscn")
	assert(_scenario_dialogue.current_speaker() == "오퍼레이터")
	var expected_texts := [
		"적의 본대가 사거리 안으로 들어왔어요. 모선이 직접 근처까지 왔다는건 그만큼 적도 급하다는 거겠죠.",
		"모선의 엔진을 파괴하기 전까지는 접근하기 힘들기 때문에. 정확히 장거리 저격을 통해 모선의 엔진을 폭발시킬 거에요",
		"이를 위해서 정확한 사격 제원을 산출하기 위해서 시간을 벌어야 해요.",
		"적 모선의 공격을 유도해 모선의 이동을 묶고, 아군 관측소가 제원을 전달할 시간을 버는게 임무입니다.",
	]
	assert(_scenario_dialogue.dialogue.size() == expected_texts.size())
	for expected_text in expected_texts:
		assert(_scenario_dialogue.current_text() == expected_text)
		_scenario_dialogue.advance()
	assert(not _scenario_dialogue.active)
	assert(not _news_banner.visible)
	print("STORY_HANGAR_STAGE_05_CHECK passed")
	get_tree().quit(0)


func _build_news_banner() -> void:
	_news_banner = PanelContainer.new()
	_news_banner.name = "NewsBanner"
	_news_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_news_banner.offset_left = -190.0
	_news_banner.offset_top = 4.0
	_news_banner.offset_right = 190.0
	_news_banner.offset_bottom = 28.0
	_news_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_news_banner.z_index = 100
	_news_banner.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.94)
	panel_style.border_color = NEWS_GREEN
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(2)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 3.0
	panel_style.content_margin_bottom = 3.0
	_news_banner.add_theme_stylebox_override("panel", panel_style)
	add_child(_news_banner)

	_news_label = Label.new()
	_news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_news_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_news_label.add_theme_font_size_override("font_size", 9)
	_news_label.add_theme_color_override("font_color", NEWS_GREEN)
	_news_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_news_banner.add_child(_news_label)

	_news_timer = Timer.new()
	_news_timer.name = "NewsTimer"
	_news_timer.one_shot = true
	_news_timer.wait_time = NEWS_DISPLAY_SECONDS
	_news_timer.timeout.connect(_hide_story_news_headline)
	add_child(_news_timer)


func _on_hangar_dialogue_finished(_scenario_id: String) -> void:
	_show_story_news_headline()


func _show_story_news_headline() -> void:
	var headline := str(STORY_NEWS_HEADLINES.get(GameSession.story_deployment_scene_path, ""))
	if headline.is_empty():
		return
	_news_label.text = "NEWS // %s" % headline
	_news_banner.visible = true
	_news_timer.start()


func _hide_story_news_headline() -> void:
	_news_banner.visible = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for y in range(0, int(size.y), 6):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.25, 0.27, 0.08), 1.0)
	_draw_panel(Rect2(8, 38, 168, 148))
	_draw_panel(Rect2(184, 38, 288, 148))
	_draw_panel(Rect2(8, 194, 464, 68))
	draw_line(Vector2(184, 31), Vector2(472, 31), LINE, 1.0)
	draw_arc(Vector2(336, 107), 59.0, 0.0, TAU, 64, Color(0.18, 0.48, 0.48, 0.28), 1.0)
	draw_arc(Vector2(336, 107), 48.0, -2.5, 0.7, 32, Color(0.36, 0.88, 0.82, 0.35), 1.0)
	draw_line(Vector2(273, 107), Vector2(399, 107), Color(0.3, 0.7, 0.68, 0.14), 1.0)
	draw_line(Vector2(336, 47), Vector2(336, 167), Color(0.3, 0.7, 0.68, 0.14), 1.0)


func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, LINE, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(13, 0), CYAN, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, 13), CYAN, 2.0)


func _build_interface() -> void:
	_make_label(self, "SUBJECT//12", Vector2(9, 5), Vector2(130, 18), 14, CYAN)
	_make_label(self, "HANGAR / LOADOUT ASSEMBLY", Vector2(105, 7), Vector2(220, 16), 9, MUTED)
	_make_label(self, "FRAME 01", Vector2(405, 7), Vector2(67, 16), 9, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_make_label(self, "01  PART CONFIGURATION", Vector2(14, 43), Vector2(156, 14), 8, MUTED)
	_make_label(self, "02  ASSEMBLED FRAME", Vector2(190, 43), Vector2(150, 14), 8, MUTED)
	_make_label(self, "03  SYSTEM OUTPUT", Vector2(14, 199), Vector2(140, 13), 8, MUTED)

	for index in SLOT_ORDER.size():
		var slot: MechLoadout.MechSlot = SLOT_ORDER[index]
		var button := Button.new()
		button.position = Vector2(14, 59 + index * 20)
		button.size = Vector2(156, 18)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 8)
		button.add_theme_stylebox_override("normal", _style(PANEL_ALT, LINE))
		button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
		button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
		button.add_theme_stylebox_override("focus", _style(Color("17343a"), CYAN))
		button.pressed.connect(_open_part_picker.bind(slot))
		add_child(button)
		_slot_buttons[slot] = button

	_status_label = _make_label(self, "EDITING", Vector2(380, 43), Vector2(84, 14), 8, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_make_label(self, "FRONT WIREFRAME PREVIEW", Vector2(255, 169), Vector2(162, 11), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	var stat_defs := [
		["ARMOR", 600.0],
		["FIREPOWER", 160.0],
		["MOBILITY", 100.0],
		["COOLING", 100.0],
		["POWER", 100.0],
		["WEIGHT", 100.0],
	]
	for index in stat_defs.size():
		var column := index % 3
		var row := index / 3
		var origin := Vector2(14 + column * 116, 214 + row * 20)
		var stat_name: String = stat_defs[index][0]
		_make_label(self, stat_name, origin, Vector2(52, 10), 7, MUTED)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.position = origin + Vector2(0, 10)
		bar.size = Vector2(106, 8)
		bar.max_value = stat_defs[index][1]
		bar.add_theme_stylebox_override("background", _style(Color("081216"), Color("1b363d"), 0))
		bar.add_theme_stylebox_override("fill", _style(CYAN, CYAN, 0))
		add_child(bar)
		var value_label := _make_label(self, "0", origin + Vector2(52, -1), Vector2(54, 10), 7, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_stat_bars[stat_name] = {"bar": bar, "label": value_label}

	_validation_label = _make_label(self, "", Vector2(365, 213), Vector2(101, 21), 7, RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_validation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_button = Button.new()
	_confirm_button.position = Vector2(365, 237)
	_confirm_button.size = Vector2(101, 19)
	_confirm_button.text = "CONFIRM LOADOUT"
	if GameSession.selected_game_mode == GameSession.GameMode.ENDLESS:
		_confirm_button.text = "DEPLOY ENDLESS"
	elif GameSession.selected_game_mode == GameSession.GameMode.STORY:
		_confirm_button.text = "DEPLOY STORY"
	_confirm_button.add_theme_font_size_override("font_size", 8)
	_confirm_button.add_theme_color_override("font_color", BG)
	_confirm_button.add_theme_color_override("font_disabled_color", MUTED)
	_confirm_button.add_theme_stylebox_override("normal", _style(CYAN, CYAN))
	_confirm_button.add_theme_stylebox_override("hover", _style(Color("8ff9e9"), Color("8ff9e9")))
	_confirm_button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER))
	_confirm_button.add_theme_stylebox_override("disabled", _style(Color("17282d"), LINE))
	_confirm_button.pressed.connect(_confirm_loadout)
	add_child(_confirm_button)

	_main_menu_button = Button.new()
	_main_menu_button.position = Vector2(365, 194)
	_main_menu_button.size = Vector2(101, 16)
	_main_menu_button.text = "MAIN MENU"
	_main_menu_button.add_theme_font_size_override("font_size", 7)
	_main_menu_button.add_theme_stylebox_override("normal", _style(PANEL_ALT, LINE))
	_main_menu_button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
	_main_menu_button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
	_main_menu_button.pressed.connect(_return_to_main_menu)
	add_child(_main_menu_button)

	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.04, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(24, 25)
	panel.size = Vector2(432, 220)
	panel.add_theme_stylebox_override("panel", _style(PANEL_ALT, CYAN, 2))
	_overlay.add_child(panel)

	_overlay_title = _make_label(panel, "SELECT PART", Vector2(12, 8), Vector2(330, 17), 11, CYAN)
	_make_label(panel, "SELECT COMPONENT / REVIEW / EQUIP", Vector2(12, 26), Vector2(300, 12), 7, MUTED)

	var close := Button.new()
	close.position = Vector2(398, 8)
	close.size = Vector2(24, 18)
	close.text = "X"
	close.add_theme_font_size_override("font_size", 9)
	close.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	close.add_theme_stylebox_override("hover", _style(Color("351a1a"), RED))
	close.pressed.connect(_close_part_picker)
	panel.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 43)
	scroll.size = Vector2(190, 164)
	panel.add_child(scroll)
	_candidate_list = VBoxContainer.new()
	_candidate_list.custom_minimum_size = Vector2(180, 0)
	_candidate_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_candidate_list)

	var divider := ColorRect.new()
	divider.position = Vector2(207, 43)
	divider.size = Vector2(1, 164)
	divider.color = LINE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_detail_name = _make_label(panel, "COMPONENT", Vector2(216, 43), Vector2(202, 17), 10, TEXT)
	_detail_kind = _make_label(panel, "SYSTEM", Vector2(216, 61), Vector2(202, 11), 7, AMBER)
	_detail_description = _make_label(panel, "", Vector2(216, 76), Vector2(202, 43), 7, TEXT)
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_stats = _make_label(panel, "", Vector2(216, 123), Vector2(202, 25), 7, MUTED)
	_detail_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_weapon = _make_label(panel, "", Vector2(216, 150), Vector2(202, 27), 7, CYAN)
	_detail_weapon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_equip_button = Button.new()
	_equip_button.position = Vector2(216, 181)
	_equip_button.size = Vector2(202, 26)
	_equip_button.text = "EQUIP"
	_equip_button.add_theme_font_size_override("font_size", 9)
	_equip_button.add_theme_color_override("font_color", BG)
	_equip_button.add_theme_color_override("font_disabled_color", MUTED)
	_equip_button.add_theme_stylebox_override("normal", _style(CYAN, CYAN))
	_equip_button.add_theme_stylebox_override("hover", _style(Color("8ff9e9"), Color("8ff9e9")))
	_equip_button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER))
	_equip_button.add_theme_stylebox_override("disabled", _style(Color("17282d"), LINE))
	_equip_button.pressed.connect(_equip_pending_part)
	panel.add_child(_equip_button)


func _build_catalog() -> bool:
	_part_catalog = MechPartCatalog.new()
	if not _part_catalog.load_file(PARTS_DATA_PATH):
		push_error("Unable to initialize Hangar part catalog")
		return false
	_catalog = _part_catalog.parts_by_type
	return true


func _initial_loadout() -> MechLoadout:
	var saved_loadout := GameSession.load_saved_player_loadout(_part_catalog)
	if saved_loadout != null and _loadout_matches_deployment_policy(saved_loadout):
		return saved_loadout
	if _is_stage_02_story_deployment():
		var fallback := _create_stage_02_fallback_loadout()
		GameSession.player_mech_loadout = fallback.copy()
		return fallback
	var fallback := _part_catalog.create_default_loadout()
	assert(_loadout_matches_deployment_policy(fallback))
	return fallback


func _is_stage_02_story_deployment() -> bool:
	return (
		GameSession.selected_game_mode == GameSession.GameMode.STORY
		and GameSession.story_deployment_scene_path == STAGE_02_PATH
	)


func _loadout_matches_deployment_policy(loadout: MechLoadout) -> bool:
	if not _has_deployment_part_restrictions():
		return true
	if loadout == null or not loadout.is_valid():
		return false
	for slot in SLOT_ORDER:
		if not _is_part_allowed_for_deployment(slot, loadout.part_for_slot(slot)):
			return false
	return true


func _is_part_allowed_for_deployment(slot: MechLoadout.MechSlot, part: MechPartSpec) -> bool:
	if not _has_deployment_part_restrictions():
		return true
	if part == null:
		return _is_optional(slot)
	if _is_stage_02_story_deployment():
		return part.part_id in STAGE_02_ALLOWED_PART_IDS[slot]
	return part.designation in STAGE_03_ALLOWED_PART_DESIGNATIONS[slot]


func _has_deployment_part_restrictions() -> bool:
	return (
		GameSession.selected_game_mode == GameSession.GameMode.STORY
		and GameSession.story_deployment_scene_path in [STAGE_02_PATH, STAGE_03_PATH]
	)


func _create_stage_02_fallback_loadout() -> MechLoadout:
	var loadout := MechLoadout.new()
	for slot in SLOT_ORDER:
		var part_id: String = STAGE_02_FALLBACK_PART_IDS[slot]
		loadout.set_part(slot, _part_catalog.parts_by_id[part_id])
	assert(loadout.is_valid())
	return loadout


func _open_part_picker(slot: MechLoadout.MechSlot) -> void:
	_active_slot = slot
	_overlay_title.text = "SELECT // %s" % SLOT_NAMES[slot]
	_candidate_parts.clear()
	for child in _candidate_list.get_children():
		_candidate_list.remove_child(child)
		child.queue_free()

	if _is_optional(slot):
		_add_candidate_button(null)
	var expected_type := _part_type_for_slot(slot)
	for part: MechPartSpec in _catalog.get(expected_type, []):
		if _is_part_allowed_for_deployment(slot, part):
			_add_candidate_button(part)
	_pending_part = _working_loadout.part_for_slot(_active_slot)
	_update_candidate_details()
	_overlay.visible = true


func _add_candidate_button(part: MechPartSpec) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 20)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 8)
	button.toggle_mode = true
	button.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	button.add_theme_stylebox_override("hover", _style(Color("17343a"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("0a171b"), AMBER))
	var equipped_part := _working_loadout.part_for_slot(_active_slot)
	var marker := ">" if equipped_part == part else " "
	if part == null:
		button.text = " %s -- EMPTY MOUNT --" % marker
		button.add_theme_color_override("font_color", MUTED)
	else:
		button.text = " %s %s  %s" % [marker, part.designation, part.display_name]
	button.pressed.connect(_preview_candidate.bind(part))
	_candidate_parts[button] = part
	_candidate_list.add_child(button)


func _preview_candidate(part: MechPartSpec) -> void:
	_pending_part = part
	_update_candidate_details()


func _update_candidate_details() -> void:
	for button: Button in _candidate_parts:
		button.set_pressed_no_signal(_candidate_parts[button] == _pending_part)

	var equipped_part := _working_loadout.part_for_slot(_active_slot)
	var already_equipped := equipped_part == _pending_part
	_equip_button.disabled = already_equipped
	if already_equipped:
		_equip_button.text = "EQUIPPED"
	elif _pending_part == null:
		_equip_button.text = "REMOVE"
	else:
		_equip_button.text = "EQUIP"

	if _pending_part == null:
		_detail_name.text = "EMPTY MOUNT"
		_detail_kind.text = "NO COMPONENT"
		_detail_description.text = (
			"선택한 백팩 파츠를 제거하고 장착부를 비웁니다."
			if _active_slot == MechLoadout.MechSlot.BACKPACK
			else "선택한 팔 파츠를 제거하고 장착부를 비웁니다."
		)
		_detail_stats.text = "ARMOR 0    WEIGHT 0\nPOWER +0   MOBILITY +0"
		_detail_weapon.text = ""
		return

	_detail_name.text = "%s // %s" % [_pending_part.designation, _pending_part.display_name]
	_detail_description.text = _pending_part.description
	_detail_stats.text = "ARMOR %.0f    WEIGHT %.0f\nPOWER %+.0f   MOBILITY %+.0f" % [
		_pending_part.armor,
		_pending_part.weight,
		_pending_part.power_generation - _pending_part.power_draw,
		_pending_part.mobility,
	]
	if _pending_part.sensor_range > 0.0:
		_detail_stats.text += "\nSENSOR %.0f / %.2fs   TRACK %d/%d" % [
			_pending_part.sensor_range,
			_pending_part.sensor_period,
			_pending_part.enemy_track_limit,
			_pending_part.projectile_track_limit,
		]
	if _pending_part.weapon == null:
		var type_name: String = MechPartSpec.PartType.keys()[_pending_part.part_type]
		_detail_kind.text = "SYSTEM // %s" % type_name
		_detail_weapon.text = ""
		return

	var weapon := _pending_part.weapon
	var family: String = WeaponSpec.WeaponFamily.keys()[weapon.weapon_family]
	_detail_kind.text = "WEAPON // %s" % family
	_detail_weapon.text = "RATE %.0f RPM   RANGE %.0f-%.0f\nMAG %d          RELOAD %.1fs" % [
		weapon.fire_rate * 60.0,
		weapon.effective_range,
		weapon.max_range,
		weapon.magazine_capacity,
		weapon.reload_duration,
	]


func _equip_pending_part() -> void:
	_select_part(_pending_part)


func _select_part(part: MechPartSpec) -> void:
	_working_loadout.set_part(_active_slot, part)
	_confirmed = false
	_overlay.visible = false
	_refresh()


func _close_part_picker() -> void:
	_overlay.visible = false


func _confirm_loadout() -> void:
	if not _loadout_matches_deployment_policy(_working_loadout):
		_working_loadout = (
			_create_stage_02_fallback_loadout()
			if _is_stage_02_story_deployment()
			else _part_catalog.create_default_loadout()
		)
		_refresh()
	if not _working_loadout.is_valid():
		return
	GameSession.confirm_player_loadout(_working_loadout)
	_confirmed = true
	_confirm_button.disabled = true
	if not SceneTransition.transition_failed.is_connected(_on_scene_transition_failed):
		SceneTransition.transition_failed.connect(_on_scene_transition_failed)
	var scene_path := _deployment_scene_path()
	var error := SceneTransition.transition_to(scene_path)
	if error != OK:
		_confirm_button.disabled = false
		push_error("Unable to open combat scene: %s" % error_string(error))


func _return_to_main_menu() -> void:
	_confirm_button.disabled = true
	_main_menu_button.disabled = true
	if not SceneTransition.transition_failed.is_connected(_on_scene_transition_failed):
		SceneTransition.transition_failed.connect(_on_scene_transition_failed)
	var error := SceneTransition.transition_to(MAIN_MENU_SCENE_PATH)
	if error != OK:
		_confirm_button.disabled = false
		_main_menu_button.disabled = false
		push_error("Unable to open main menu: %s" % error_string(error))


func _on_scene_transition_failed(scene_path: String, error: Error) -> void:
	if scene_path not in [MAIN_MENU_SCENE_PATH, SKIRMISH_SCENE_PATH, ENDLESS_SCENE_PATH, STORY_STAGE_SELECT_PATH, GameSession.story_deployment_scene_path]:
		return
	_confirm_button.disabled = false
	_main_menu_button.disabled = false
	push_error("Unable to change scene: %s" % error_string(error))


func _deployment_scene_path() -> String:
	match GameSession.selected_game_mode:
		GameSession.GameMode.ENDLESS:
			return ENDLESS_SCENE_PATH
		GameSession.GameMode.STORY:
			return (
				GameSession.story_deployment_scene_path
				if not GameSession.story_deployment_scene_path.is_empty()
				else STORY_STAGE_SELECT_PATH
			)
	return SKIRMISH_SCENE_PATH


func _refresh() -> void:
	for slot in SLOT_ORDER:
		var button: Button = _slot_buttons[slot]
		var part := _working_loadout.part_for_slot(slot)
		var required := not _is_optional(slot)
		var marker := "*" if required else " "
		button.text = " %s %-9s  %s" % [marker, SLOT_NAMES[slot], part.designation if part != null else "-- EMPTY --"]

	mech_preview.display(_working_loadout)
	var totals := _working_loadout.stats()
	_set_stat("ARMOR", totals["armor"], "%.0f" % totals["armor"])
	_set_stat("FIREPOWER", totals["firepower"], "%.0f" % totals["firepower"])
	_set_stat("MOBILITY", maxf(totals["mobility"], 0.0), "%.0f" % totals["mobility"])
	_set_stat("COOLING", totals["cooling"], "%.0f" % totals["cooling"])
	var power_net: float = totals["power_generation"] - totals["power_draw"]
	_set_stat("POWER", clampf(power_net + 50.0, 0.0, 100.0), "%+.0f" % power_net)
	var capacity: float = totals["weight_capacity"]
	var weight_ratio: float = totals["weight"] / capacity * 100.0 if capacity > 0.0 else 100.0
	_set_stat("WEIGHT", weight_ratio, "%.0f/%.0f" % [totals["weight"], capacity])

	var errors := _working_loadout.validation_errors()
	_confirm_button.disabled = not errors.is_empty()
	if not errors.is_empty():
		_status_label.text = "INVALID"
		_status_label.add_theme_color_override("font_color", RED)
		_validation_label.text = errors[0]
	elif _confirmed:
		_status_label.text = "CONFIRMED"
		_status_label.add_theme_color_override("font_color", CYAN)
		_validation_label.text = "READY FOR BATTLE"
		_validation_label.add_theme_color_override("font_color", CYAN)
	else:
		_status_label.text = "EDITING"
		_status_label.add_theme_color_override("font_color", AMBER)
		_validation_label.text = "LOADOUT VALID"
		_validation_label.add_theme_color_override("font_color", TEXT)


func _set_stat(stat_name: String, value: float, value_text: String) -> void:
	var entry: Dictionary = _stat_bars[stat_name]
	var bar: ProgressBar = entry["bar"]
	bar.value = value
	var label: Label = entry["label"]
	label.text = value_text
	if stat_name == "WEIGHT":
		var color := RED if value > 100.0 else AMBER
		bar.add_theme_stylebox_override("fill", _style(color, color, 0))
	elif stat_name == "POWER":
		var color := RED if value < 50.0 else CYAN
		bar.add_theme_stylebox_override("fill", _style(color, color, 0))


func _part_type_for_slot(slot: MechLoadout.MechSlot) -> MechPartSpec.PartType:
	match slot:
		MechLoadout.MechSlot.HEAD:
			return MechPartSpec.PartType.HEAD
		MechLoadout.MechSlot.BODY:
			return MechPartSpec.PartType.BODY
		MechLoadout.MechSlot.LEFT_ARM, MechLoadout.MechSlot.RIGHT_ARM:
			return MechPartSpec.PartType.ARM_EQUIPMENT
		MechLoadout.MechSlot.BACKPACK:
			return MechPartSpec.PartType.BACKPACK
		MechLoadout.MechSlot.LEGS:
			return MechPartSpec.PartType.LEGS
	return MechPartSpec.PartType.BODY


func _is_optional(slot: MechLoadout.MechSlot) -> bool:
	return slot in [MechLoadout.MechSlot.LEFT_ARM, MechLoadout.MechSlot.RIGHT_ARM, MechLoadout.MechSlot.BACKPACK]


func _make_label(
	parent: Control,
	text: String,
	position: Vector2,
	size: Vector2,
	font_size: int,
	color: Color,
	alignment := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _style(fill: Color, border: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _overlay.visible:
		_close_part_picker()
		get_viewport().set_input_as_handled()
