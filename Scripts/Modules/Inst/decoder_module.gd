class_name DecoderModule
extends ShipModule

signal note_missed(step_index: int, lane: StringName)

const LEFT := 0
const RIGHT := 1
const NOTE_SIZE := Vector2(10.0, 3.0)
const NOTE_HIT_Y := 23.0
const BUTTON_TOP_Y := 21.0
const BUTTON_BOTTOM_Y := 28.0
const SCREEN_BOTTOM_Y := 31.0
const LINE_SPACING := 6.0
const NOTE_LEAD_BEATS := 4.0
const IMPACT_ATTACK := 0.15
const LEFT_COLOR := Color(0.7765, 0.3176, 0.5922)
const RIGHT_COLOR := Color(0.4510, 0.7451, 0.8275)
const HIT_COLOR := Color(1.0, 0.7137, 0.0)
const IMPACT_FADED_COLOR := Color(1.0, 0.7137, 0.0, 0.4)
const FAILED_LEFT_COLOR := Color("#7a367b")
const FAILED_RIGHT_COLOR := Color("#3c5e8b")

const DEMO_BINARY_DATA := """bpm 120 / steps 2

L . R . L R LR .
L . . R L:8 . R .
R L R L LR . . .
L:20 . . . R . R .
"""

@onready var screen: TextureRect = $"../Screen"
@onready var left_notes: Control = $"../Screen/LeftNotes"
@onready var right_notes: Control = $"../Screen/RightNotes"
@onready var left_screen_button: TextureRect = $"../Screen/LeftButton"
@onready var left_screen_button_pressed: TextureRect = (
    $"../Screen/LeftButtonPressed"
)
@onready var right_screen_button: TextureRect = $"../Screen/RightButton"
@onready var right_screen_button_pressed: TextureRect = (
    $"../Screen/RightButtonPressed"
)
@onready var left_impact: ColorRect = $"../Screen/LeftImpactArea"
@onready var right_impact: ColorRect = $"../Screen/RightImpactArea"
@onready var z_button: TextureRect = $"../ZButton"
@onready var z_button_pressed: TextureRect = $"../ZButtonPressed"
@onready var x_button: TextureRect = $"../XButton"
@onready var x_button_pressed: TextureRect = $"../XButtonPressed"

var bpm := 120.0
var steps_per_beat := 2
var combo := 0
var perfects := 0
var misses := 0
var decode_progress := 1.0
var decode_accuracy := 1.0
var missed_notes: Array[Dictionary] = []

var _notes: Array[Dictionary] = []
var _mouse_held := [false, false]
var _key_held := [false, false]
var _lane_held := [false, false]
var _active_hold_notes: Array = [null, null]
var _active_impact_notes: Array = [null, null]
var _impact_elapsed := [0.0, 0.0]
var _step_duration := 0.25
var _note_speed := 12.0
var _song_time := 0.0
var _chart_end_time := 0.0
var _playing := false
var _earned_score_units := 0
var _judged_score_units := 0
var _total_score_units := 0
var _printed_current_message := false
var _chart_message_id: StringName
var _screen_material: ShaderMaterial


func _init() -> void:
    module_name = "Decoder"
    add_input_port(&"power")
    add_output_port(&"data")


func _ready() -> void:
    super._ready()
    _screen_material = screen.material as ShaderMaterial
    left_impact.material = left_impact.material.duplicate()
    right_impact.material = right_impact.material.duplicate()
    z_button.gui_input.connect(_on_button_gui_input.bind(LEFT))
    x_button.gui_input.connect(_on_button_gui_input.bind(RIGHT))
    play_binary_data(DEMO_BINARY_DATA)


func _process(delta: float) -> void:
    if not _playing:
        return
    
    _song_time += delta
    _update_notes()
    _update_holds()
    _update_impacts(delta)
    decode_progress = clampf(
        maxf(_song_time, 0.0) / maxf(_chart_end_time, 0.001),
        0.0,
        1.0
    )
    
    if _song_time >= _chart_end_time and _all_notes_judged():
        decode_progress = 1.0
        if _notes.is_empty():
            _playing = false
            print(
                (
                    "[decoder score] %d/%d units, %.1f%% accuracy, "
                    + "%d perfects, %d misses, %d combo"
                )
                % [
                    _earned_score_units,
                    _total_score_units,
                    decode_accuracy * 100.0,
                    perfects,
                    misses,
                    combo,
                ]
            )


func _input(event: InputEvent) -> void:
    if event.is_action_released("Grab"):
        _set_mouse_held(LEFT, false)
        _set_mouse_held(RIGHT, false)
    
    var key_event := event as InputEventKey
    if key_event == null or key_event.echo:
        return
    
    var lane := -1
    if key_event.keycode == KEY_Z or key_event.physical_keycode == KEY_Z:
        lane = LEFT
    elif key_event.keycode == KEY_X or key_event.physical_keycode == KEY_X:
        lane = RIGHT
    
    if lane < 0:
        return
    if key_event.pressed and not _is_module_hovered():
        return
    
    _key_held[lane] = key_event.pressed
    _refresh_lane_held(lane)
    get_viewport().set_input_as_handled()


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if not output_data.has("comms"):
        _printed_current_message = false
        _chart_message_id = &""
        send_data(&"data", output_data)
        return
    
    var comms: Dictionary = output_data["comms"]
    var message_id: StringName = comms["message_id"]
    if message_id != _chart_message_id:
        _chart_message_id = message_id
        play_binary_data(DEMO_BINARY_DATA)
    
    var signal_text: String = comms["signal_text"]
    var receive_start := float(comms["receive_start_ratio"])
    var transmission_progress := float(comms["transmission_progress"])
    var visible_progress := minf(transmission_progress, decode_progress)
    var start := floori(signal_text.length() * receive_start)
    var end := floori(signal_text.length() * visible_progress)
    
    comms["stage"] = &"decoded"
    comms["decode_progress"] = decode_progress
    comms["decode_accuracy"] = decode_accuracy
    comms["missed_notes"] = missed_notes.duplicate(true)
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


func play_binary_data(data: String) -> void:
    _clear_chart()
    var lines := data.replace("\r", "").split("\n")
    var header := lines[0].strip_edges().split(" ", false)
    bpm = float(header[1])
    steps_per_beat = int(header[4])
    _step_duration = 60.0 / bpm / float(steps_per_beat)
    _note_speed = bpm / 60.0 * LINE_SPACING
    _screen_material.set_shader_parameter("bpm", bpm)
    
    var step_index := 0
    for line_index: int in range(1, lines.size()):
        var line := lines[line_index].strip_edges()
        if line.is_empty():
            continue
        
        for token: String in line.split(" ", false):
            _parse_step(token, step_index)
            step_index += 1
    
    _song_time = -NOTE_LEAD_BEATS * 60.0 / bpm
    decode_progress = 0.0
    decode_accuracy = 1.0
    _playing = not _notes.is_empty()


func _parse_step(token: String, step_index: int) -> void:
    if token == ".":
        return
    
    var parts := token.split(":", false, 1)
    var lanes := parts[0]
    var duration_steps := 1
    if parts.size() > 1:
        duration_steps = maxi(int(parts[1]), 1)
    
    if lanes.contains("L"):
        _create_note(LEFT, step_index, duration_steps)
    if lanes.contains("R"):
        _create_note(RIGHT, step_index, duration_steps)


func _create_note(
    lane: int,
    step_index: int,
    duration_steps: int
) -> void:
    var note_node := Control.new()
    note_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var trail := ColorRect.new()
    var head := ColorRect.new()
    var note_color := LEFT_COLOR if lane == LEFT else RIGHT_COLOR
    var trail_height := 0.0
    
    if duration_steps > 1:
        trail_height = duration_steps * _step_duration * _note_speed
        trail.position = Vector2(-1.5, -trail_height)
        trail.size = Vector2(3.0, trail_height)
        trail.color = note_color
        trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        note_node.add_child(trail)
    
    head.position = Vector2(-NOTE_SIZE.x * 0.5, 0.0)
    head.size = NOTE_SIZE
    head.color = note_color
    head.mouse_filter = Control.MOUSE_FILTER_IGNORE
    note_node.add_child(head)
    _note_parent(lane).add_child(note_node)
    
    var note_time := step_index * _step_duration
    var hold_end_time := (
        note_time + (duration_steps - 1) * _step_duration
    )
    var note := {
        "lane": lane,
        "step": step_index,
        "time": note_time,
        "duration_steps": duration_steps,
        "hold_end_time": hold_end_time,
        "units_awarded": 0,
        "state": &"pending",
        "miss_reported": false,
        "trail_height": trail_height,
        "node": note_node,
        "head": head,
        "trail": trail,
    }
    _notes.append(note)
    _total_score_units += duration_steps
    _chart_end_time = maxf(_chart_end_time, hold_end_time)


func _update_notes() -> void:
    for index: int in range(_notes.size() - 1, -1, -1):
        var note := _notes[index]
        var note_node := note["node"] as Control
        note_node.position.y = (
            NOTE_HIT_Y
            + (_song_time - float(note["time"])) * _note_speed
        )
        
        if (
            note["state"] == &"pending"
            and note_node.position.y > BUTTON_BOTTOM_Y
        ):
            _miss_note(note)
        
        if note["state"] != &"pending" and note["state"] != &"missed":
            _clip_hit_note_at_button(note)
        
        var trail_top := note_node.position.y - float(note["trail_height"])
        var passed_button := (
            trail_top > BUTTON_TOP_Y
            if float(note["trail_height"]) > 0.0
            else note_node.position.y > BUTTON_BOTTOM_Y
        )
        var should_remove := (
            trail_top > SCREEN_BOTTOM_Y
            if note["state"] == &"missed"
            else passed_button
        )
        if should_remove:
            _end_impact_if_note(note)
            note_node.queue_free()
            _notes.remove_at(index)


func _update_holds() -> void:
    for lane: int in [LEFT, RIGHT]:
        var note = _active_hold_notes[lane]
        if note == null:
            continue
        
        var duration_steps := int(note["duration_steps"])
        while (
            int(note["units_awarded"]) < duration_steps
            and _song_time >= (
                float(note["time"])
                + int(note["units_awarded"]) * _step_duration
            )
        ):
            if not _lane_held[lane]:
                _drop_hold(note)
                break
            _award_score_unit(note)
        
        if int(note["units_awarded"]) >= duration_steps:
            note["state"] = &"complete"
            _active_hold_notes[lane] = null


func _update_impacts(delta: float) -> void:
    for lane: int in [LEFT, RIGHT]:
        var note = _active_impact_notes[lane]
        if note == null:
            continue
        
        var note_node := note["node"] as Control
        var trail_top := note_node.position.y - float(note["trail_height"])
        if not _lane_held[lane] or trail_top > BUTTON_BOTTOM_Y:
            _end_impact(lane)
            continue
        
        _impact_elapsed[lane] += delta
        var material := _impact_material(lane)
        var attack := minf(_impact_elapsed[lane] / IMPACT_ATTACK, 1.0)
        var width := lerpf(14.0, 4.0, attack)
        if attack >= 1.0:
            width = float(randi_range(4, 6))
        material.set_shader_parameter("bar_width_px", width)
        material.set_shader_parameter(
            "top_color",
            HIT_COLOR.lerp(IMPACT_FADED_COLOR, attack)
        )
        material.set_shader_parameter(
            "gradient_midpoint",
            randf_range(0.2, 0.7)
        )


func _try_hit(lane: int) -> void:
    var closest_note: Dictionary = {}
    var closest_distance := INF
    for note: Dictionary in _notes:
        if note["lane"] != lane or note["state"] != &"pending":
            continue
        
        var note_node := note["node"] as Control
        if not _note_is_in_button(note_node):
            continue
        
        var distance := absf(note_node.position.y - NOTE_HIT_Y)
        if distance < closest_distance:
            closest_distance = distance
            closest_note = note
    
    if closest_note.is_empty():
        return
    
    closest_note["state"] = &"holding"
    perfects += 1
    combo += 1
    _set_note_color(closest_note, HIT_COLOR)
    _award_score_unit(closest_note)
    if int(closest_note["duration_steps"]) > 1:
        _active_hold_notes[lane] = closest_note
    else:
        closest_note["state"] = &"complete"
    _start_impact(lane, closest_note)


func _award_score_unit(note: Dictionary) -> void:
    note["units_awarded"] = int(note["units_awarded"]) + 1
    _earned_score_units += 1
    _judged_score_units += 1
    _update_accuracy()


func _miss_note(note: Dictionary) -> void:
    note["state"] = &"missed"
    _judged_score_units += int(note["duration_steps"])
    combo = 0
    _register_miss(note)
    _update_accuracy()


func _drop_hold(note: Dictionary) -> void:
    if note["state"] != &"holding":
        return
    
    var remaining := (
        int(note["duration_steps"]) - int(note["units_awarded"])
    )
    _judged_score_units += remaining
    note["state"] = &"failed"
    combo = 0
    _active_hold_notes[int(note["lane"])] = null
    var trail := note["trail"] as ColorRect
    if trail.get_parent() != null:
        trail.color = (
            FAILED_LEFT_COLOR
            if note["lane"] == LEFT
            else FAILED_RIGHT_COLOR
        )
    _register_miss(note)
    _update_accuracy()


func _register_miss(note: Dictionary) -> void:
    if note["miss_reported"]:
        return
    
    note["miss_reported"] = true
    misses += 1
    var lane_name: StringName = &"left" if note["lane"] == LEFT else &"right"
    missed_notes.append({
        "step": note["step"],
        "lane": lane_name,
    })
    note_missed.emit(note["step"], lane_name)


func _update_accuracy() -> void:
    decode_accuracy = (
        float(_earned_score_units) / float(_judged_score_units)
        if _judged_score_units > 0
        else 1.0
    )


func _on_button_gui_input(event: InputEvent, lane: int) -> void:
    if event.is_action_pressed("Grab"):
        _set_mouse_held(lane, true)
        visual.bring_to_foreground()
        _physical_button(lane).accept_event()
    elif event.is_action_released("Grab"):
        _set_mouse_held(lane, false)
        _physical_button(lane).accept_event()


func _set_mouse_held(lane: int, value: bool) -> void:
    _mouse_held[lane] = value
    _refresh_lane_held(lane)


func _refresh_lane_held(lane: int) -> void:
    var held: bool = _mouse_held[lane] or _key_held[lane]
    if held == _lane_held[lane]:
        return
    
    _lane_held[lane] = held
    _set_physical_button(lane, held)
    _set_screen_button(lane, held)
    if held:
        _try_hit(lane)
    else:
        var hold_note = _active_hold_notes[lane]
        if hold_note != null:
            _drop_hold(hold_note)
        _end_impact(lane)


func _start_impact(lane: int, note: Dictionary) -> void:
    _active_impact_notes[lane] = note
    _impact_elapsed[lane] = 0.0
    var impact := _impact_area(lane)
    var material := _impact_material(lane)
    impact.visible = true
    material.set_shader_parameter("bar_width_px", 14.0)
    material.set_shader_parameter("top_color", HIT_COLOR)


func _end_impact(lane: int) -> void:
    _active_impact_notes[lane] = null
    _impact_area(lane).visible = false
    _set_screen_button(lane, false)


func _end_impact_if_note(note: Dictionary) -> void:
    for lane: int in [LEFT, RIGHT]:
        if _active_impact_notes[lane] == note:
            _end_impact(lane)


func _set_note_color(note: Dictionary, color: Color) -> void:
    (note["head"] as ColorRect).color = color
    var trail := note["trail"] as ColorRect
    if trail.get_parent() != null:
        trail.color = color


func _clip_hit_note_at_button(note: Dictionary) -> void:
    var note_node := note["node"] as Control
    var head := note["head"] as ColorRect
    var trail := note["trail"] as ColorRect
    head.visible = note_node.position.y + NOTE_SIZE.y <= BUTTON_BOTTOM_Y
    if trail.get_parent() == null:
        return
    
    var trail_top := note_node.position.y - float(note["trail_height"])
    var trail_bottom := minf(note_node.position.y, BUTTON_TOP_Y)
    trail.position.y = trail_top - note_node.position.y
    trail.size.y = maxf(trail_bottom - trail_top, 0.0)
    trail.visible = trail.size.y > 0.0


func _note_is_in_button(note_node: Control) -> bool:
    return (
        note_node.position.y + NOTE_SIZE.y >= BUTTON_TOP_Y
        and note_node.position.y <= BUTTON_BOTTOM_Y
    )


func _all_notes_judged() -> bool:
    for note: Dictionary in _notes:
        if note["state"] == &"pending" or note["state"] == &"holding":
            return false
    return true


func _clear_chart() -> void:
    for note: Dictionary in _notes:
        (note["node"] as Control).queue_free()
    _notes.clear()
    _active_hold_notes = [null, null]
    _active_impact_notes = [null, null]
    _impact_elapsed = [0.0, 0.0]
    _chart_end_time = 0.0
    _earned_score_units = 0
    _judged_score_units = 0
    _total_score_units = 0
    combo = 0
    perfects = 0
    misses = 0
    missed_notes.clear()
    _end_impact(LEFT)
    _end_impact(RIGHT)


func _is_module_hovered() -> bool:
    var hovered := get_viewport().gui_get_hovered_control()
    return (
        hovered == visual
        or (hovered != null and visual.is_ancestor_of(hovered))
    )


func _set_physical_button(lane: int, pressed: bool) -> void:
    _physical_button(lane).visible = true
    _physical_pressed_button(lane).visible = pressed


func _set_screen_button(lane: int, pressed: bool) -> void:
    _screen_button(lane).visible = true
    _screen_pressed_button(lane).visible = pressed


func _physical_button(lane: int) -> TextureRect:
    return z_button if lane == LEFT else x_button


func _physical_pressed_button(lane: int) -> TextureRect:
    return z_button_pressed if lane == LEFT else x_button_pressed


func _screen_button(lane: int) -> TextureRect:
    return left_screen_button if lane == LEFT else right_screen_button


func _screen_pressed_button(lane: int) -> TextureRect:
    return (
        left_screen_button_pressed
        if lane == LEFT
        else right_screen_button_pressed
    )


func _impact_area(lane: int) -> ColorRect:
    return left_impact if lane == LEFT else right_impact


func _impact_material(lane: int) -> ShaderMaterial:
    return _impact_area(lane).material as ShaderMaterial


func _note_parent(lane: int) -> Control:
    return left_notes if lane == LEFT else right_notes


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
