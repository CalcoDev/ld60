class_name CommsOutModule
extends ShipModule


func _init() -> void:
    module_name = "Comms Out"
    add_input_port(&"power")


func process_input(_port_name: StringName, _data: Dictionary) -> void:
    pass
