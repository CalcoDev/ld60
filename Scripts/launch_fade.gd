extends CanvasLayer

@export var fade_duration := 3.0

@onready var black: ColorRect = $Black


func _ready() -> void:
    get_tree().paused = true
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(black, "modulate:a", 0.0, fade_duration)
    await tween.finished
    get_tree().paused = false
    queue_free()
