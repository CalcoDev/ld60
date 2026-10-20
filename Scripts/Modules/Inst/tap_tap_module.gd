class_name TapTapModule
extends ShipModule

@export var pressed_texture: Texture2D

@onready var tap_area: Control = $"../TapArea"
@onready var tap_sfx: AudioStreamPlayer = $TapSfx

var _normal_texture: Texture2D
var _pressed := false


func _init() -> void:
    module_name = "Tap Tap Machine"
    add_input_port(&"power")
    add_output_port(&"data")


func _ready() -> void:
    super._ready()
    _normal_texture = visual.texture
    tap_area.gui_input.connect(_on_tap_area_gui_input)


func _input(event: InputEvent) -> void:
    if _pressed and event.is_action_released("Grab"):
        _pressed = false
        visual.texture = _normal_texture


func process_input(_port_name: StringName, data: Dictionary) -> void:
    send_data(&"data", data)


func _on_tap_area_gui_input(event: InputEvent) -> void:
    if not event.is_action_pressed("Grab"):
        return
    
    _pressed = true
    visual.texture = pressed_texture
    visual.bring_to_foreground()
    tap_sfx.play()
    tap_area.accept_event()
