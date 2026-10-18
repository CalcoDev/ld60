class_name DecoderModule
extends ShipModule

var decode_progress := 1.0
var decode_accuracy := 1.0
var _printed_current_message := false


func _init() -> void:
    module_name = "Decoder"
    add_input_port(&"power")
    add_output_port(&"data")


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if not output_data.has("comms"):
        _printed_current_message = false
        send_data(&"data", output_data)
        return
    
    var comms: Dictionary = output_data["comms"]
    var signal_text: String = comms["signal_text"]
    var receive_start := float(comms["receive_start_ratio"])
    var transmission_progress := float(comms["transmission_progress"])
    var visible_progress := minf(transmission_progress, decode_progress)
    var start := floori(signal_text.length() * receive_start)
    var end := floori(signal_text.length() * visible_progress)
    
    comms["stage"] = &"decoded"
    comms["decode_progress"] = decode_progress
    comms["decode_accuracy"] = decode_accuracy
    comms["decoded_text"] = _decode_text(
        signal_text,
        start,
        end,
        comms["message_id"]
    )
    comms["display_text"] = comms["decoded_text"]
    
    if transmission_progress >= 1.0 and not _printed_current_message:
        _printed_current_message = true
        print("[decoded] %s" % comms["decoded_text"])
    
    send_data(&"data", output_data)


func _decode_text(
    signal_text: String,
    start: int,
    end: int,
    message_id: StringName
) -> String:
    var result := "?".repeat(start)
    var random := RandomNumberGenerator.new()
    random.seed = hash(message_id)
    
    for index in range(start, end):
        var character := signal_text.substr(index, 1)
        
        if (
            decode_accuracy < 0.9
            and character != " "
            and random.randf() > decode_accuracy
        ):
            result += "#"
        else:
            result += character
    
    return result
