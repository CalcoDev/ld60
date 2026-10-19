class_name ThrusterModule
extends ShipModule

const LEVER_TOP_Y := 23.0
const LEVER_BOTTOM_Y := 88.0

@export var thrust_per_second := 4.0

@onready var lever_top: TextureRect = $"../LeverTop"
@onready var lever_arm_pivot: Control = $"../LeverArmPivot"

var current_thrust := 0.0
var _lever_dragging := false
var _lever_drag_offset_y := 0.0


func _init() -> void:
    module_name = "Thruster"
    add_input_port(&"power")
    add_output_port(&"data")


func _ready() -> void:
    super._ready()
    visual.gui_input.connect(_on_module_gui_input)
    lever_top.gui_input.connect(_on_lever_top_gui_input)
    _set_lever_position(lever_top.position.y)


func _process(_delta: float) -> void:
    if not _lever_dragging:
        return
    
    if not Input.is_action_pressed("Grab"):
        _lever_dragging = false
        return
    
    var lever_parent := lever_top.get_parent() as Control
    _set_lever_position(
        lever_parent.get_local_mouse_position().y
        - _lever_drag_offset_y
    )


func _input(event: InputEvent) -> void:
    if event.is_action_released("Grab"):
        _lever_dragging = false


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if output_data.get("power", false):
        output_data["thrust"] = current_thrust * thrust_per_second
    
    send_data(&"data", output_data)


func _on_lever_top_gui_input(event: InputEvent) -> void:
    if _is_grab_double_click(event):
        _lever_dragging = false
        _set_lever_position(
            (LEVER_TOP_Y + LEVER_BOTTOM_Y) * 0.5
        )
        lever_top.accept_event()
        return
    
    if not event.is_action_pressed("Grab"):
        return
    
    var lever_parent := lever_top.get_parent() as Control
    _lever_dragging = true
    _lever_drag_offset_y = (
        lever_parent.get_local_mouse_position().y
        - lever_top.position.y
    )
    if visual != null:
        visual.bring_to_foreground()
    lever_top.accept_event()


func _on_module_gui_input(event: InputEvent) -> void:
    if _is_grab_double_click(event):
        _lever_dragging = false
        _set_lever_position(
            (LEVER_TOP_Y + LEVER_BOTTOM_Y) * 0.5
        )


func _is_grab_double_click(event: InputEvent) -> bool:
    var mouse_event := event as InputEventMouseButton
    return (
        mouse_event != null
        and mouse_event.double_click
        and event.is_action_pressed("Grab")
    )


func _set_lever_position(value: float) -> void:
    lever_top.position.y = clampf(
        value,
        LEVER_TOP_Y,
        LEVER_BOTTOM_Y
    )
    var travel := inverse_lerp(
        LEVER_TOP_Y,
        LEVER_BOTTOM_Y,
        lever_top.position.y
    )
    current_thrust = lerpf(1.0, -1.0, travel)
    lever_arm_pivot.scale.y = current_thrust
