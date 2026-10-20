class_name CommsInModule
extends ShipModule

signal transmission_finished

const FALLBACK_CHARACTERS_PER_SECOND := 12.0
const MAX_DIAL_ANGLE := PI * 0.5
const MAX_SIGNAL_FREQUENCY := 200.0
const MAX_WAVE_FREQUENCY := 4.5
const MAX_WAVE_AMPLITUDE := 15.0
const SYNTH_MIN_FREQUENCY := 130.81
const SYNTH_MAX_FREQUENCY := 523.25
const TUNING_TOLERANCE := 0.1
const INDICATOR_INTERVAL := 0.33
const INCOMING_SCROLL_SPEED := 10.0
const INCOMING_SCROLL_WRAP := 44.0
const INCOMING_COLOR := Color(0.9216, 0.9294, 0.9137)

@export_range(4.0, 30.0, 1.0) var click_step_degrees := 12.0

@onready var screen: TextureRect = $"../Screen"
@onready var frequency_pivot: Control = $"../DialFreq/Pivot"
@onready var frequency_dial: TextureRect = (
    $"../DialFreq/Pivot/DialInside"
)
@onready var amplitude_pivot: Control = $"../DialAmpl/Pivot"
@onready var amplitude_dial: TextureRect = (
    $"../DialAmpl/Pivot/DialInside"
)
@onready var incoming_light: TextureRect = $"../LightOn"
@onready var scrolling_text: Control = $"../TextBackground/ScrollingText"
@onready var click_sfx: AudioStreamPlayer = $ClickSfx
@onready var synth_player: AudioStreamPlayer = $SynthPlayer
@onready var incoming_sfx: AudioStreamPlayer = $IncomingSfx

var current_message: AlienDialogueMessage
var frequency := 0.0
var amplitude := 0.0

var _transmission_elapsed := 0.0
var _transmission_duration := 1.0
var _receive_start_ratio := 1.0
var _actual_frequency := 0.0
var _actual_amplitude := 0.0
var _signal_text := ""
var _latched_comms: Dictionary = {}
var _transmitting := false
var _connection_established := false
var _resolved_fonts: Array[Font] = []
var _resolved_voices: Array[AudioStream] = []
var _dragging_pivot: Control
var _last_mouse_angle := 0.0
var _click_angle_accumulator := 0.0
var _indicator_elapsed := 0.0
var _scroll_offset := 0.0
var _scroll_start_x := 0.0
var _screen_material: ShaderMaterial
var _synth_playback: AudioStreamGeneratorPlayback
var _synth_mix_rate := 22050.0
var _synth_phase := 0.0
var _synth_frequency := 261.63
var _synth_amplitude := 0.0


func _init() -> void:
    module_name = "Comms In"
    add_input_port(&"power")
    add_output_port(&"data")


func _ready() -> void:
    super._ready()
    _screen_material = screen.material as ShaderMaterial
    _scroll_start_x = scrolling_text.position.x
    frequency_dial.gui_input.connect(
        _on_dial_gui_input.bind(frequency_pivot, frequency_dial)
    )
    amplitude_dial.gui_input.connect(
        _on_dial_gui_input.bind(amplitude_pivot, amplitude_dial)
    )
    _set_dial_rotation(frequency_pivot, frequency_pivot.rotation)
    _set_dial_rotation(amplitude_pivot, amplitude_pivot.rotation)
    var generator := synth_player.stream as AudioStreamGenerator
    _synth_mix_rate = generator.mix_rate
    synth_player.play()
    _synth_playback = (
        synth_player.get_stream_playback()
        as AudioStreamGeneratorPlayback
    )


func _process(delta: float) -> void:
    _update_dial_drag()
    _update_incoming_visuals(delta)
    _try_establish_connection()
    _fill_synth_buffer()


func _input(event: InputEvent) -> void:
    if event.is_action_released("Grab"):
        _dragging_pivot = null


func play_message(message: AlienDialogueMessage) -> void:
    if not _begin_message(message):
        return
    await transmission_finished


func establish_connection() -> void:
    if current_message == null or _connection_established:
        return
    _connection_established = true
    visual.set_force_lit(false)
    incoming_sfx.stop()
    
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
    
    if not data.get("power", false):
        send_data(&"data", output_data)
        return
    
    if current_message == null:
        if not _latched_comms.is_empty():
            output_data["comms"] = _latched_comms.duplicate(true)
        send_data(&"data", output_data)
        return
    
    var delta := float(data.get("delta", 0.0))
    
    if _transmitting:
        _transmission_elapsed += delta
    
    if _connection_established:
        output_data["comms"] = _make_comms_data()
    
    if _get_transmission_progress() >= 1.0:
        if _connection_established:
            print("[received] %s" % output_data["comms"]["display_text"])
            _latched_comms = output_data["comms"].duplicate(true)
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
    _latched_comms.clear()
    _transmission_elapsed = 0.0
    _transmitting = false
    _connection_established = false
    _receive_start_ratio = 1.0
    _indicator_elapsed = INDICATOR_INTERVAL
    visual.set_force_lit(true)
    incoming_sfx.play()
    
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
    _screen_material.set_shader_parameter(
        "wave1_frequency",
        clampf(_actual_frequency / MAX_SIGNAL_FREQUENCY, 0.0, 1.0)
        * MAX_WAVE_FREQUENCY
    )
    _screen_material.set_shader_parameter(
        "wave1_amplitude_px",
        clampf(_actual_amplitude, 0.0, 1.0)
        * MAX_WAVE_AMPLITUDE
    )
    
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
    visual.set_force_lit(false)
    incoming_sfx.stop()
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


func _on_dial_gui_input(
    event: InputEvent,
    pivot: Control,
    dial: TextureRect
) -> void:
    var mouse_event := event as InputEventMouseButton
    if (
        mouse_event != null
        and mouse_event.double_click
        and event.is_action_pressed("Grab")
    ):
        _dragging_pivot = null
        _click_angle_accumulator = 0.0
        _set_dial_rotation(pivot, 0.0)
        dial.accept_event()
        return
    
    if not event.is_action_pressed("Grab"):
        return
    
    _dragging_pivot = pivot
    _click_angle_accumulator = 0.0
    _last_mouse_angle = _get_mouse_angle(pivot)
    if visual != null:
        visual.bring_to_foreground()
    dial.accept_event()


func _update_dial_drag() -> void:
    if _dragging_pivot == null:
        return
    
    if not Input.is_action_pressed("Grab"):
        _dragging_pivot = null
        return
    
    var mouse_angle := _get_mouse_angle(_dragging_pivot)
    var mouse_delta := wrapf(
        mouse_angle - _last_mouse_angle,
        -PI,
        PI
    )
    _last_mouse_angle = mouse_angle
    var old_rotation := _dragging_pivot.rotation
    _set_dial_rotation(
        _dragging_pivot,
        _dragging_pivot.rotation + mouse_delta
    )
    _play_dial_clicks(absf(_dragging_pivot.rotation - old_rotation))


func _play_dial_clicks(angle_moved: float) -> void:
    var click_step := deg_to_rad(click_step_degrees)
    _click_angle_accumulator += angle_moved
    while _click_angle_accumulator >= click_step:
        _click_angle_accumulator -= click_step
        click_sfx.play()


func _fill_synth_buffer() -> void:
    if _synth_playback == null:
        return
    
    var target_frequency := (
        SYNTH_MIN_FREQUENCY
        * pow(
            SYNTH_MAX_FREQUENCY / SYNTH_MIN_FREQUENCY,
            frequency
        )
    )
    var target_amplitude := amplitude
    var frequency_weight := 1.0 - exp(-20.0 / _synth_mix_rate)
    var amplitude_weight := 1.0 - exp(-30.0 / _synth_mix_rate)
    var frames_available := _synth_playback.get_frames_available()
    for _frame: int in range(frames_available):
        _synth_frequency = lerpf(
            _synth_frequency,
            target_frequency,
            frequency_weight
        )
        _synth_amplitude = lerpf(
            _synth_amplitude,
            target_amplitude,
            amplitude_weight
        )
        var sample := sin(_synth_phase * TAU) * _synth_amplitude
        _synth_playback.push_frame(Vector2(sample, sample))
        _synth_phase = fposmod(
            _synth_phase + _synth_frequency / _synth_mix_rate,
            1.0
        )


func _set_dial_rotation(pivot: Control, value: float) -> void:
    pivot.rotation = clampf(value, -MAX_DIAL_ANGLE, MAX_DIAL_ANGLE)
    var normalized_value := inverse_lerp(
        -MAX_DIAL_ANGLE,
        MAX_DIAL_ANGLE,
        pivot.rotation
    )
    
    if pivot == frequency_pivot:
        frequency = normalized_value
        _screen_material.set_shader_parameter(
            "wave2_frequency",
            frequency * MAX_WAVE_FREQUENCY
        )
    else:
        amplitude = normalized_value
        _screen_material.set_shader_parameter(
            "wave2_amplitude_px",
            amplitude * MAX_WAVE_AMPLITUDE
        )


func _get_mouse_angle(pivot: Control) -> float:
    var dial_parent := pivot.get_parent() as Control
    return (
        dial_parent.get_local_mouse_position()
        - pivot.position
    ).angle()


func _try_establish_connection() -> void:
    if current_message == null or _connection_established:
        return
    
    var power_data: Dictionary = input_data.get(&"power", {})
    if not power_data.get("power", false):
        return
    
    var target_frequency := clampf(
        _actual_frequency / MAX_SIGNAL_FREQUENCY,
        0.0,
        1.0
    )
    var target_amplitude := clampf(_actual_amplitude, 0.0, 1.0)
    if (
        absf(frequency - target_frequency) <= TUNING_TOLERANCE
        and absf(amplitude - target_amplitude) <= TUNING_TOLERANCE
    ):
        establish_connection()


func _update_incoming_visuals(delta: float) -> void:
    var incoming := current_message != null and not _connection_established
    if not incoming:
        incoming_light.visible = false
        scrolling_text.visible = false
        _indicator_elapsed = 0.0
        _scroll_offset = 0.0
        scrolling_text.position.x = _scroll_start_x
        return
    
    _indicator_elapsed = fposmod(
        _indicator_elapsed + delta,
        INDICATOR_INTERVAL * 2.0
    )
    var bright := _indicator_elapsed >= INDICATOR_INTERVAL
    incoming_light.visible = bright
    scrolling_text.visible = bright
    scrolling_text.modulate = INCOMING_COLOR
    _scroll_offset = fposmod(
        _scroll_offset + INCOMING_SCROLL_SPEED * delta,
        INCOMING_SCROLL_WRAP
    )
    scrolling_text.position.x = _scroll_start_x + _scroll_offset
