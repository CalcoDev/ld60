class_name ModulePort
extends Node

signal on_data_received(data: Dictionary)
signal on_connection_changed(other_port: ModulePort)

enum Direction {
    INPUT,
    OUTPUT,
}

var port_name: StringName
var direction: Direction
var connected_port: ModulePort


func connect_port(other_port: ModulePort) -> void:
    if other_port == null or other_port == self:
        return
    
    if direction == other_port.direction:
        push_warning("Ports must connect an output to an input.")
        return
    
    disconnect_port()
    other_port.disconnect_port()
    
    connected_port = other_port
    other_port.connected_port = self
    
    on_connection_changed.emit(other_port)
    other_port.on_connection_changed.emit(self)


func disconnect_port() -> void:
    if connected_port == null:
        return
    
    var other_port := connected_port
    connected_port = null
    other_port.connected_port = null
    
    on_connection_changed.emit(null)
    other_port.on_connection_changed.emit(null)


func send(data: Dictionary) -> void:
    if direction != Direction.OUTPUT or connected_port == null:
        return
    
    connected_port.on_data_received.emit(data.duplicate(true))
