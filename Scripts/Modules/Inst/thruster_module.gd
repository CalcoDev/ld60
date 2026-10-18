class_name ThrusterModule
extends ShipModule

@export var thrust_per_second := 4.0


func _init() -> void:
    module_name = "Thruster"
    add_input_port(&"power")
    add_output_port(&"data")


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if output_data.get("power", false):
        output_data["thrust"] = thrust_per_second
    
    send_data(&"data", output_data)
