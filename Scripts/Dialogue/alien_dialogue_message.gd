class_name AlienDialogueMessage
extends RefCounted

var message_id: StringName
var original_text: String
var race: AlienRaceData

var glyph_fonts_override: Array[Font] = []
var voice_clips_override: Array[AudioStream] = []

var target_frequency_override: Variant
var target_amplitude_override: Variant
var connection_buffer_override: Variant
var transmission_duration_override: Variant


func _init(
    text: String,
    id_value: StringName = &""
) -> void:
    original_text = text
    message_id = id_value if id_value else StringName(str(hash(text)))


func from(race_data: AlienRaceData) -> AlienDialogueMessage:
    race = race_data
    return self


func id(id_value: StringName) -> AlienDialogueMessage:
    message_id = id_value
    return self


func frequency(value: float) -> AlienDialogueMessage:
    target_frequency_override = value
    return self


func amplitude(value: float) -> AlienDialogueMessage:
    target_amplitude_override = value
    return self


func tuned_to(
    frequency_value: float,
    amplitude_value: float
) -> AlienDialogueMessage:
    return frequency(frequency_value).amplitude(amplitude_value)


func buffer(seconds: float) -> AlienDialogueMessage:
    connection_buffer_override = seconds
    return self


func duration(seconds: float) -> AlienDialogueMessage:
    transmission_duration_override = seconds
    return self


func font(font_value: Font) -> AlienDialogueMessage:
    glyph_fonts_override = [font_value]
    return self


func fonts(font_pool: Array[Font]) -> AlienDialogueMessage:
    glyph_fonts_override = font_pool.duplicate()
    return self


func voice(voice_clip: AudioStream) -> AlienDialogueMessage:
    voice_clips_override = [voice_clip]
    return self


func voices(voice_pool: Array[AudioStream]) -> AlienDialogueMessage:
    voice_clips_override = voice_pool.duplicate()
    return self


func send(comms_in: CommsInModule) -> void:
    if comms_in == null:
        push_error("Alien dialogue message has no Comms In module.")
        return
    
    await comms_in.play_message(self)
