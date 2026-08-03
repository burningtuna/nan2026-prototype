extends CanvasLayer

signal transition_finished(scene_path: String)
signal transition_failed(scene_path: String, error: Error)

const CLOSE_SECONDS := 0.55
const OPEN_SECONDS := 0.55
const CLOSED_HOLD_SECONDS := 0.12

@onready var curtain: Control = $Curtain
@onready var top_door: TextureRect = $Curtain/TopDoor
@onready var bottom_door: TextureRect = $Curtain/BottomDoor
@onready var loading_panel: PanelContainer = $Curtain/LoadingPanel
@onready var status_label: Label = $Curtain/LoadingPanel/Status

var transitioning := false


func _ready() -> void:
	curtain.resized.connect(_reset_open_positions)
	curtain.visible = false
	call_deferred("_reset_open_positions")


func transition_to(scene_path: String) -> Error:
	if transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	transitioning = true
	_run_transition(scene_path)
	return OK


func _run_transition(scene_path: String) -> void:
	curtain.visible = true
	loading_panel.visible = false
	_place_doors_open()
	await _animate_doors(true)
	loading_panel.visible = true
	status_label.text = "TRANSFER // LOADING"
	await get_tree().process_frame
	var next_scene := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if next_scene == null:
		await _fail_transition(scene_path, ERR_CANT_CREATE)
		return
	await get_tree().create_timer(CLOSED_HOLD_SECONDS, true, false, true).timeout
	var error := get_tree().change_scene_to_packed(next_scene)
	if error != OK:
		await _fail_transition(scene_path, error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	loading_panel.visible = false
	await _animate_doors(false)
	curtain.visible = false
	transitioning = false
	transition_finished.emit(scene_path)
	if OS.get_cmdline_user_args().has("--scene-transition-smoke"):
		await get_tree().process_frame
		await get_tree().process_frame
		assert(get_tree().current_scene.scene_file_path == scene_path)
		assert(not curtain.visible)
		assert(top_door.position.is_equal_approx(Vector2(0.0, -top_door.size.y)))
		assert(bottom_door.position.is_equal_approx(Vector2(0.0, curtain.size.y)))
		print("SCENE_TRANSITION_CHECK passed")


func _fail_transition(scene_path: String, error: Error) -> void:
	status_label.text = "TRANSFER // FAILED"
	await get_tree().create_timer(0.5, true, false, true).timeout
	loading_panel.visible = false
	await _animate_doors(false)
	curtain.visible = false
	transitioning = false
	transition_failed.emit(scene_path, error)


func _animate_doors(closing: bool) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_IN_OUT)
	var top_target := Vector2(0.0, 0.0) if closing else Vector2(0.0, -top_door.size.y)
	var bottom_target := (
		Vector2(0.0, curtain.size.y * 0.5)
		if closing
		else Vector2(0.0, curtain.size.y)
	)
	tween.tween_property(top_door, "position", top_target, CLOSE_SECONDS if closing else OPEN_SECONDS)
	tween.tween_property(
		bottom_door,
		"position",
		bottom_target,
		CLOSE_SECONDS if closing else OPEN_SECONDS
	)
	await tween.finished


func _reset_open_positions() -> void:
	if transitioning and curtain.visible:
		return
	_place_doors_open()


func _place_doors_open() -> void:
	top_door.position = Vector2(0.0, -top_door.size.y)
	bottom_door.position = Vector2(0.0, curtain.size.y)
