class_name MainScreenBootMenu
extends Control

signal boot_finished

@export var boot_duration := 3.0
@export var spin_speed := 3.0

@onready var screen_mask: Control = $ScreenMask
@onready var label: Label = $ScreenMask/Label
@onready var spinny_thing_rotator: Control = (
    $ScreenMask/CompanyLogo/SpinnyThingRotator
)
@onready var loader = $ScreenMask/Loader

var _elapsed := 0.0
var _label_start_y := 0.0
var _finished := false


func _ready() -> void:
    _label_start_y = label.position.y


func _process(delta: float) -> void:
    if _finished:
        return
    
    _elapsed = minf(_elapsed + delta, boot_duration)
    var progress := _elapsed / maxf(boot_duration, 0.001)
    label.visible_characters = floori(label.text.length() * progress)
    loader.fill = progress
    spinny_thing_rotator.rotation += spin_speed * delta
    
    var maximum_scroll := maxf(
        label.size.y - screen_mask.size.y + _label_start_y,
        0.0
    )
    var scroll_progress := smoothstep(0.2, 1.0, progress)
    label.position.y = _label_start_y - maximum_scroll * scroll_progress
    
    if progress >= 1.0:
        _finished = true
        boot_finished.emit()
