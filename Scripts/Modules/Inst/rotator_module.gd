class_name RotatorModule
extends ShipModule

@export var rotation_per_second := 0.5


func _init() -> void:
    module_name = "Rotator"
    add_input_port(&"power")
    add_output_port(&"data")


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if output_data.get("power", false):
        output_data["rotation"] = rotation_per_second
    
    send_data(&"data", output_data)
