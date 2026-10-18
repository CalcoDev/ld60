class_name MainScreenModule
extends ShipModule

var player_position := Vector2.ZERO
var player_angle := 0.0
var player_velocity := 0.0

var _print_time := 0.0
var _has_movement_data := false
var _last_comms_output := ""


func _init() -> void:
    module_name = "Main Screen"
    var input_port := add_input_port(&"data")
    add_output_port(&"power")
    input_port.on_connection_changed.connect(_on_screen_connection_changed)


func _physics_process(delta: float) -> void:
    send_data(
        &"power",
        {
            "power": true,
            "delta": delta,
        }
    )
    
    _print_time += delta
    if _has_movement_data and _print_time >= 1.0:
        _print_time = 0.0
        print(
            "position=%s angle=%.2f velocity=%.2f"
            % [player_position, player_angle, player_velocity]
        )


func process_input(_port_name: StringName, data: Dictionary) -> void:
    if not data.get("power", false):
        return
    
    if data.has("comms"):
        _process_comms(data["comms"])
        return
    
    _last_comms_output = ""
    var delta: float = data.get("delta", 0.0)
    var rotation: float = data.get("rotation", 0.0)
    var thrust: float = data.get("thrust", 0.0)
    
    _has_movement_data = data.has("rotation") or data.has("thrust")
    player_angle += rotation * delta
    player_velocity += thrust * delta
    player_position += (
        Vector2.RIGHT.rotated(player_angle) * player_velocity * delta
    )


func _on_screen_connection_changed(other_port: ModulePort) -> void:
    if other_port == null:
        print("showing idle ui")
        return
    
    var connected_module := other_port.get_parent() as ShipModule
    if connected_module != null:
        print("showing ui for %s" % connected_module.module_name)


func _process_comms(comms: Dictionary) -> void:
    if float(comms.get("transmission_progress", 0.0)) < 1.0:
        return
    
    var stage: StringName = comms.get("stage", &"received")
    var output: String = comms.get("display_text", "")
    var printed_output := "[%s] %s" % [stage, output]
    
    if printed_output == _last_comms_output:
        return
    
    _last_comms_output = printed_output
    print(printed_output)
