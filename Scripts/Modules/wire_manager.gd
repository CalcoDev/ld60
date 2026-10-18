class_name WireManager
extends Node2D

@export var output_jack_texture: Texture2D = preload(
    "res://Assets/Modules/Ports/port_plugged_in_out.png"
)
@export var input_jack_texture: Texture2D = preload(
    "res://Assets/Modules/Ports/port_plugged_in_in.png"
)
@export var wire_color := Color(0.16, 0.2, 0.27)
@export var wire_width := 5.0
@export_range(0.0, 1.0, 0.05) var tighten_below_ratio := 0.5
@export var tighten_speed := 120.0

var _active_wire: ModuleWire


func _ready() -> void:
    add_to_group(&"wire_manager")


func _input(event: InputEvent) -> void:
    if _active_wire != null and event.is_action_released("Grab"):
        _finish_active_wire()
        get_viewport().set_input_as_handled()


func begin_wire(port_area: ModulePortArea) -> void:
    if (
        _active_wire != null
        or port_area == null
        or port_area.module_port == null
    ):
        return
    
    if port_area.module_port.connected_port != null:
        var connected_wire := _find_wire(port_area)
        if connected_wire == null:
            return
        connected_wire.pick_up(port_area)
        port_area.module_port.disconnect_port()
        _active_wire = connected_wire
        return
    
    if port_area.module_port.direction != ModulePort.Direction.OUTPUT:
        return
    
    var wire := ModuleWire.new()
    wire.output_jack_texture = output_jack_texture
    wire.input_jack_texture = input_jack_texture
    wire.wire_color = wire_color
    wire.wire_width = wire_width
    wire.tighten_below_ratio = tighten_below_ratio
    wire.tighten_speed = tighten_speed
    add_child(wire)
    wire.begin_drag(port_area)
    _active_wire = wire


func _finish_active_wire() -> void:
    var target_area := _find_hovered_port_area()
    if _can_connect_to(target_area):
        _active_wire.finish_connection(target_area)
        _active_wire.source_area.module_port.connect_port(
            _active_wire.target_area.module_port
        )
    else:
        _active_wire.drop()
    
    _active_wire = null


func _can_connect_to(port_area: ModulePortArea) -> bool:
    return (
        port_area != null
        and port_area != _active_wire.get_anchored_area()
        and port_area.module_port != null
        and port_area.module_port.direction
        == _active_wire.get_dragged_direction()
        and port_area.module_port.connected_port == null
    )


func _find_wire(port_area: ModulePortArea) -> ModuleWire:
    for child: Node in get_children():
        if child is ModuleWire and (child as ModuleWire).has_port(port_area):
            return child as ModuleWire
    
    return null


func _find_hovered_port_area() -> ModulePortArea:
    var current := get_viewport().gui_get_hovered_control()
    while current != null:
        if current is ModulePortArea:
            return current as ModulePortArea
        current = current.get_parent() as Control
    
    return null
