class_name CommsInModule
extends ShipModule

signal transmission_finished

const FALLBACK_CHARACTERS_PER_SECOND := 12.0

var current_message: AlienDialogueMessage

var _waiting_elapsed := 0.0
var _transmission_elapsed := 0.0
var _connection_buffer := 0.0
var _transmission_duration := 1.0
var _receive_start_ratio := 1.0
var _actual_frequency := 0.0
var _actual_amplitude := 0.0
var _signal_text := ""
var _transmitting := false
var _connection_established := false
var _resolved_fonts: Array[Font] = []
var _resolved_voices: Array[AudioStream] = []


func _init() -> void:
    module_name = "Comms In"
    add_input_port(&"power")
    add_output_port(&"data")


func play_message(message: AlienDialogueMessage) -> void:
    if not _begin_message(message):
        return
    await transmission_finished


func establish_connection() -> void:
    if current_message == null or _connection_established:
        return
    _connection_established = true
    
    if _transmitting:
        _receive_start_ratio = _get_transmission_progress()
    else:
        _receive_start_ratio = 0.0
        _start_transmission()
    
    print(
        "connection established at %.0f%%"
        % (_receive_start_ratio * 100.0)
    )


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if current_message == null or not data.get("power", false):
        send_data(&"data", output_data)
        return
    
    var delta := float(data.get("delta", 0.0))
    
    if not _transmitting:
        _waiting_elapsed += delta
        if _waiting_elapsed >= _connection_buffer:
            _start_transmission()
    else:
        _transmission_elapsed += delta
    
    if _connection_established:
        output_data["comms"] = _make_comms_data()
    
    if _get_transmission_progress() >= 1.0:
        if _connection_established:
            print("[received] %s" % output_data["comms"]["display_text"])
        else:
            print("[received] missed entire transmission")
        
        send_data(&"data", output_data)
        _finish_message()
        return
    
    send_data(&"data", output_data)


func _begin_message(message: AlienDialogueMessage) -> bool:
    if message.race == null:
        push_error("Alien dialogue message has no race.")
        return false
    
    current_message = message
    _waiting_elapsed = 0.0
    _transmission_elapsed = 0.0
    _transmitting = false
    _connection_established = false
    _receive_start_ratio = 1.0
    
    var race := message.race
    var seed_value := hash(message.message_id)
    var random := RandomNumberGenerator.new()
    random.seed = seed_value
    
    var target_frequency := _resolve_float(
        message.target_frequency_override,
        race.target_frequency
    )
    var target_amplitude := _resolve_float(
        message.target_amplitude_override,
        race.target_amplitude
    )
    
    _actual_frequency = target_frequency + random.randf_range(
        -race.frequency_variance,
        race.frequency_variance
    )
    _actual_amplitude = target_amplitude + random.randf_range(
        -race.amplitude_variance,
        race.amplitude_variance
    )
    _connection_buffer = _resolve_float(
        message.connection_buffer_override,
        race.default_connection_buffer
    )
    _resolved_fonts = (
        message.glyph_fonts_override.duplicate()
        if not message.glyph_fonts_override.is_empty()
        else race.default_glyph_fonts.duplicate()
    )
    _resolved_voices = (
        message.voice_clips_override.duplicate()
        if not message.voice_clips_override.is_empty()
        else race.default_voice_clips.duplicate()
    )
    _signal_text = GleepGlorpLanguages.encode(
        message.original_text,
        race.language
    )
    _transmission_duration = _resolve_duration(message)
    
    print(
        "incoming %s transmission: tune to %.2f / %.2f"
        % [race.display_name, _actual_frequency, _actual_amplitude]
    )
    return true


func _start_transmission() -> void:
    if _transmitting:
        return
    
    _transmitting = true
    _transmission_elapsed = 0.0
    print("transmission started")


func _finish_message() -> void:
    current_message = null
    _transmitting = false
    transmission_finished.emit()


func _make_comms_data() -> Dictionary:
    var progress := _get_transmission_progress()
    var end := floori(_signal_text.length() * progress)
    var start := floori(_signal_text.length() * _receive_start_ratio)
    var display_text := "?".repeat(start)
    
    if end > start:
        display_text += _signal_text.substr(start, end - start)
    
    return {
        "message_id": current_message.message_id,
        "race": current_message.race,
        "language": current_message.race.language,
        "original_text": current_message.original_text,
        "signal_text": _signal_text,
        "display_text": display_text,
        "stage": &"received",
        "connection_established": _connection_established,
        "transmission_progress": progress,
        "receive_start_ratio": _receive_start_ratio,
        "decode_progress": 1.0,
        "decode_accuracy": 1.0,
        "frequency": _actual_frequency,
        "amplitude": _actual_amplitude,
        "glyph_fonts": _resolved_fonts,
        "voice_clips": _resolved_voices,
    }


func _get_transmission_progress() -> float:
    if not _transmitting:
        return 0.0
    return clampf(_transmission_elapsed / _transmission_duration, 0.0, 1.0)


func _resolve_duration(message: AlienDialogueMessage) -> float:
    if message.transmission_duration_override != null:
        return maxf(float(message.transmission_duration_override), 0.01)
    if not _resolved_voices.is_empty():
        return maxf(_resolved_voices[0].get_length(), 0.01)
    return maxf(
        message.original_text.length() / FALLBACK_CHARACTERS_PER_SECOND,
        1.0
    )


func _resolve_float(override_value: Variant, fallback: float) -> float:
    return fallback if override_value == null else float(override_value)
