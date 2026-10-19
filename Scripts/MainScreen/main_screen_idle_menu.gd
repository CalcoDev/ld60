class_name MainScreenIdleMenu
extends Control

signal pause_requested

@onready var label: Label = $ScreenMask/Label
@onready var pause_button: Button = $ScreenMask/Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    label.pivot_offset = label.size * 0.5
    pause_button.pressed.connect(pause_requested.emit)
    _start_label_animation()


func _start_label_animation() -> void:
    var tween := create_tween().set_loops()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(label, "modulate:a", 0.6, 1.2)
    tween.parallel().tween_property(label, "scale", Vector2.ONE * 0.985, 1.2)
    tween.tween_property(label, "modulate:a", 1.0, 1.2)
    tween.parallel().tween_property(label, "scale", Vector2.ONE * 1.015, 1.2)
