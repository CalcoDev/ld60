class_name MainScreenPauseMenu
extends Control

signal resume_requested

@export var dot_interval := 0.35

@onready var label: Label = $ScreenMask/Label
@onready var resume_button: Button = $ScreenMask/Button

var _dot_count := 0
var _dot_time := 0.0


func _ready() -> void:
    resume_button.pressed.connect(resume_requested.emit)
    _start_label_animation()


func _process(delta: float) -> void:
    _dot_time += delta
    if _dot_time < dot_interval:
        return
    
    _dot_time -= dot_interval
    _dot_count = (_dot_count + 1) % 4
    _set_pause_text()


func _set_pause_text() -> void:
    label.text = "PAUSED" + ".".repeat(_dot_count)


func _start_label_animation() -> void:
    var tween := create_tween().set_loops()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(label, "modulate:a", 0.6, 0.8)
    tween.parallel().tween_property(label, "scale", Vector2.ONE * 0.985, 0.8)
    tween.tween_property(label, "modulate:a", 1.0, 0.8)
    tween.parallel().tween_property(label, "scale", Vector2.ONE * 1.015, 0.8)
