@abstract
class_name ShipModule
extends Node

var module_name := "Module"
var input_ports: Dictionary = {}
var output_ports: Dictionary = {}
var input_data: Dictionary = {}
@export var always_powered := false

var visual: ModuleVisual


func _ready() -> void:
    visual = get_parent() as ModuleVisual
    _refresh_visual_power()


func add_input_port(port_name: StringName) -> ModulePort:
    var port := ModulePort.new()
    port.name = String(port_name)
    port.port_name = port_name
    port.direction = ModulePort.Direction.INPUT
    port.on_data_received.connect(_on_input_data_received.bind(port_name))
    port.on_connection_changed.connect(_on_input_connection_changed.bind(port_name))
    add_child(port)
    input_ports[port_name] = port
    return port


func add_output_port(port_name: StringName) -> ModulePort:
    var port := ModulePort.new()
    port.name = String(port_name)
    port.port_name = port_name
    port.direction = ModulePort.Direction.OUTPUT
    add_child(port)
    output_ports[port_name] = port
    return port


func get_input_port(port_name: StringName) -> ModulePort:
    return input_ports.get(port_name) as ModulePort


func get_output_port(port_name: StringName) -> ModulePort:
    return output_ports.get(port_name) as ModulePort


func send_data(port_name: StringName, data: Dictionary) -> void:
    var port := get_output_port(port_name)
    if port != null:
        port.send(data)


@abstract
func process_input(_port_name: StringName, _data: Dictionary) -> void


func _on_input_data_received(
    data: Dictionary,
    port_name: StringName
) -> void:
    input_data[port_name] = data.duplicate(true)
    _refresh_visual_power()
    process_input(port_name, input_data[port_name])


func _on_input_connection_changed(
    other_port: ModulePort,
    port_name: StringName
) -> void:
    if other_port == null:
        input_data.erase(port_name)
        _refresh_visual_power()


func _refresh_visual_power() -> void:
    if visual == null:
        return
    
    var has_power := always_powered
    
    for data: Dictionary in input_data.values():
        if data.get("power", false):
            has_power = true
            break
    
    visual.set_powered(has_power)
