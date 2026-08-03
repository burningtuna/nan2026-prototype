class_name EndlessHud
extends Control

signal retry_requested
signal hangar_requested

@onready var score_label: Label = $ScorePanel/Stack/Score
@onready var time_label: Label = $ScorePanel/Stack/Time
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_score: Label = $ResultPanel/Margin/Stack/ResultScore


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.visible = false
	$ResultPanel/Margin/Stack/Retry.pressed.connect(retry_requested.emit)
	$ResultPanel/Margin/Stack/Hangar.pressed.connect(hangar_requested.emit)


func set_score(score: int, high_score: int) -> void:
	score_label.text = "SCORE %06d  //  HIGH %06d" % [score, high_score]


func set_time(elapsed_seconds: float, tier: int) -> void:
	time_label.text = "TIME %02d:%02d  //  TIER %02d" % [
		floori(elapsed_seconds / 60.0),
		floori(elapsed_seconds) % 60,
		tier + 1,
	]


func show_game_over(score: int, high_score: int) -> void:
	result_score.text = "FINAL SCORE  %06d\nHIGH SCORE   %06d" % [score, high_score]
	result_panel.visible = true
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
