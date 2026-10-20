class_name RotatorModule
extends ShipModule

const MAX_DIAL_ANGLE := PI * 0.5

@export var rotation_per_second := 0.5
@export_range(1.0, 15.0, 0.5) var click_step_degrees := 4.0

@onready var dial_pivot: Control = $"../DialPivot"
@onready var dial: TextureRect = $"../DialPivot/Dial"
@onready var click_sfx: AudioStreamPlayer = $ClickSfx

var current_rotation := 0.0
var _dial_dragging := false
var _last_mouse_angle := 0.0
var _click_angle_accumulator := 0.0


func _init() -> void:
    module_name = "Rotator"
    add_input_port(&"power")
    add_output_port(&"data")


func _ready() -> void:
    super._ready()
    visual.gui_input.connect(_on_module_gui_input)
    dial.gui_input.connect(_on_dial_gui_input)
    _set_dial_rotation(dial_pivot.rotation)


func _process(_delta: float) -> void:
    if not _dial_dragging:
        return
    
    if not Input.is_action_pressed("Grab"):
        _dial_dragging = false
        return
    
    var mouse_angle := _get_mouse_angle()
    var mouse_delta := wrapf(
        mouse_angle - _last_mouse_angle,
        -PI,
        PI
    )
    _last_mouse_angle = mouse_angle
    var old_rotation := dial_pivot.rotation
    _set_dial_rotation(dial_pivot.rotation + mouse_delta)
    _play_rotation_clicks(absf(dial_pivot.rotation - old_rotation))


func _input(event: InputEvent) -> void:
    if event.is_action_released("Grab"):
        _dial_dragging = false


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if output_data.get("power", false):
        output_data["rotation"] = (
            current_rotation * rotation_per_second
        )
    
    send_data(&"data", output_data)


func _on_dial_gui_input(event: InputEvent) -> void:
    if _is_grab_double_click(event):
        reset_rotation()
        dial.accept_event()
        return
    
    if not event.is_action_pressed("Grab"):
        return
    
    _dial_dragging = true
    _click_angle_accumulator = 0.0
    _last_mouse_angle = _get_mouse_angle()
    if visual != null:
        visual.bring_to_foreground()
    dial.accept_event()


func _on_module_gui_input(event: InputEvent) -> void:
    if _is_grab_double_click(event):
        reset_rotation()


func reset_rotation() -> void:
    _dial_dragging = false
    _click_angle_accumulator = 0.0
    _set_dial_rotation(0.0)


func _play_rotation_clicks(angle_moved: float) -> void:
    var click_step := deg_to_rad(click_step_degrees)
    _click_angle_accumulator += angle_moved
    while _click_angle_accumulator >= click_step:
        _click_angle_accumulator -= click_step
        click_sfx.play()


func _is_grab_double_click(event: InputEvent) -> bool:
    var mouse_event := event as InputEventMouseButton
    return (
        mouse_event != null
        and mouse_event.double_click
        and event.is_action_pressed("Grab")
    )


func _set_dial_rotation(value: float) -> void:
    dial_pivot.rotation = clampf(
        value,
        -MAX_DIAL_ANGLE,
        MAX_DIAL_ANGLE
    )
    current_rotation = dial_pivot.rotation / MAX_DIAL_ANGLE


func _get_mouse_angle() -> float:
    var dial_parent := dial_pivot.get_parent() as Control
    return (
        dial_parent.get_local_mouse_position()
        - dial_pivot.position
    ).angle()
