class_name TranslatorModule
extends ShipModule

var selected_cassette: StringName


func _init() -> void:
    module_name = "Translator"
    add_input_port(&"power")
    add_output_port(&"data")


func select_cassette(cassette_id: StringName) -> void:
    selected_cassette = cassette_id


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if not output_data.has("comms"):
        send_data(&"data", output_data)
        return
    
    var comms: Dictionary = output_data["comms"]
    var race := comms["race"] as AlienRaceData
    
    comms["stage"] = &"translated"
    
    if race != null and selected_cassette == race.cassette_id:
        comms["translated_text"] = _translate(comms)
    else:
        comms["translated_text"] = comms.get("decoded_text", "")
    
    comms["display_text"] = comms["translated_text"]
    send_data(&"data", output_data)


func _translate(comms: Dictionary) -> String:
    var original_text: String = comms["original_text"]
    var receive_start := float(comms["receive_start_ratio"])
    var transmission_progress := float(comms["transmission_progress"])
    var decode_progress := float(comms["decode_progress"])
    var decode_accuracy := float(comms["decode_accuracy"])
    var visible_progress := minf(transmission_progress, decode_progress)
    var start := floori(original_text.length() * receive_start)
    var end := floori(original_text.length() * visible_progress)
    var result := ""
    var random := RandomNumberGenerator.new()
    random.seed = hash(comms["message_id"])
    
    for index in range(end):
        var character := original_text.substr(index, 1)
        
        if index < start:
            result += " " if character == " " else "?"
        elif (
            decode_accuracy < 0.9
            and character != " "
            and random.randf() > decode_accuracy
        ):
            result += "#"
        else:
            result += character
    
    return result
