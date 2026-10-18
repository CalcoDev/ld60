class_name ModuleWire
extends Node2D

enum State {
    DRAGGING,
    CONNECTED,
    DROPPED,
}

const POINT_COUNT := 48
const CONSTRAINT_ITERATIONS := 11
const MINIMUM_LENGTH := 96.0
const CABLE_SLACK := 24.0
const GRAVITY := Vector2(0.0, 900.0)
const VELOCITY_DAMPING := 0.97875
const DROP_LIFETIME := 3.0
const JACK_PADDING := Vector2(7.0, 5.0)
const JACK_CABLE_OFFSET := 26.0
const JACK_DIRECTION_RESPONSE := 20.0
const CONNECTED_JACK_DIRECTION_RESPONSE := 4.0

var output_jack_texture: Texture2D
var input_jack_texture: Texture2D
var wire_color := Color(0.16, 0.2, 0.27)
var wire_width := 5.0
var tighten_below_ratio := 0.5
var tighten_speed := 120.0

var source_area: ModulePortArea
var target_area: ModulePortArea
var state := State.DRAGGING
var dragging_source := false

var _positions: Array[Vector2] = []
var _previous_positions: Array[Vector2] = []
var _segment_length := MINIMUM_LENGTH / float(POINT_COUNT - 1)
var _line: Line2D
var _source_jack: Sprite2D
var _target_jack: Sprite2D
var _source_socket_position := Vector2.ZERO
var _target_socket_position := Vector2.ZERO
var _source_jack_direction := Vector2.DOWN
var _target_jack_direction := Vector2.DOWN


func _ready() -> void:
    _line = Line2D.new()
    _line.width = wire_width
    _line.default_color = wire_color
    _line.antialiased = true
    _line.begin_cap_mode = Line2D.LINE_CAP_ROUND
    _line.end_cap_mode = Line2D.LINE_CAP_ROUND
    _line.joint_mode = Line2D.LINE_JOINT_ROUND
    add_child(_line)
    
    _source_jack = _make_jack(output_jack_texture)
    _target_jack = _make_jack(input_jack_texture)
    add_child(_source_jack)
    add_child(_target_jack)


func _physics_process(delta: float) -> void:
    if _positions.is_empty():
        return
    
    var start_pinned := state != State.DROPPED
    var end_pinned := state != State.DROPPED
    var start_position := _positions[0]
    var end_position := _positions[-1]
    
    if state == State.DRAGGING and dragging_source:
        _source_socket_position = get_local_mouse_position()
    elif start_pinned and is_instance_valid(source_area):
        _source_socket_position = to_local(
            source_area.get_wire_anchor_position()
        )
    if state == State.DRAGGING and not dragging_source:
        _target_socket_position = get_local_mouse_position()
    elif end_pinned and is_instance_valid(target_area):
        _target_socket_position = to_local(
            target_area.get_wire_anchor_position()
        )
    
    _update_jack_directions(delta)
    if start_pinned:
        start_position = (
            _source_socket_position
            + _source_jack_direction * JACK_CABLE_OFFSET
        )
    if end_pinned:
        end_position = (
            _target_socket_position
            + _target_jack_direction * JACK_CABLE_OFFSET
        )
    
    if state != State.DROPPED:
        _update_cable_length(start_position, end_position, delta)
    
    for index: int in range(POINT_COUNT):
        if (index == 0 and start_pinned) or (
            index == POINT_COUNT - 1 and end_pinned
        ):
            continue
        
        var current := _positions[index]
        var velocity := (
            current - _previous_positions[index]
        ) * VELOCITY_DAMPING
        _previous_positions[index] = current
        _positions[index] = current + velocity + GRAVITY * delta * delta
    
    _pin_endpoints(
        start_pinned,
        end_pinned,
        start_position,
        end_position
    )
    
    for _iteration: int in range(CONSTRAINT_ITERATIONS):
        _solve_constraints(start_pinned, end_pinned)
        _pin_endpoints(
            start_pinned,
            end_pinned,
            start_position,
            end_position
        )
    
    _update_visuals()


func begin_drag(port_area: ModulePortArea) -> void:
    source_area = port_area
    state = State.DRAGGING
    dragging_source = false
    _source_socket_position = to_local(
        source_area.get_wire_anchor_position()
    )
    _target_socket_position = get_local_mouse_position()
    var start_position := (
        _source_socket_position
        + _source_jack_direction * JACK_CABLE_OFFSET
    )
    var end_position := (
        _target_socket_position
        + _target_jack_direction * JACK_CABLE_OFFSET
    )
    _positions.clear()
    _previous_positions.clear()
    
    for index: int in range(POINT_COUNT):
        var weight := float(index) / float(POINT_COUNT - 1)
        var position := start_position.lerp(end_position, weight)
        position.y += sin(weight * PI) * MINIMUM_LENGTH * 0.25
        _positions.append(position)
        _previous_positions.append(position)
    
    _update_visuals()
    _animate_jack(_source_jack)


func finish_connection(port_area: ModulePortArea) -> void:
    if dragging_source:
        source_area = port_area
        _source_socket_position = to_local(
            source_area.get_wire_anchor_position()
        )
        _animate_jack(_source_jack)
    else:
        target_area = port_area
        _target_socket_position = to_local(
            target_area.get_wire_anchor_position()
        )
        _animate_jack(_target_jack)
    state = State.CONNECTED
    
    _connect_port_signals()


func pick_up(port_area: ModulePortArea) -> void:
    _disconnect_port_signals()
    dragging_source = port_area == source_area
    if dragging_source:
        source_area = null
        _source_socket_position = get_local_mouse_position()
    else:
        target_area = null
        _target_socket_position = get_local_mouse_position()
    state = State.DRAGGING


func has_port(port_area: ModulePortArea) -> bool:
    return port_area == source_area or port_area == target_area


func get_dragged_direction() -> ModulePort.Direction:
    return (
        ModulePort.Direction.OUTPUT
        if dragging_source
        else ModulePort.Direction.INPUT
    )


func get_anchored_area() -> ModulePortArea:
    return target_area if dragging_source else source_area


func drop() -> void:
    if state == State.DROPPED:
        return
    
    state = State.DROPPED
    source_area = null
    target_area = null
    
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, DROP_LIFETIME)
    tween.finished.connect(queue_free)


func _make_jack(texture: Texture2D) -> Sprite2D:
    var jack := Sprite2D.new()
    jack.texture = texture
    jack.z_index = 1
    if texture != null:
        var visible_size := texture.get_size() - JACK_PADDING * 2.0
        jack.region_enabled = true
        jack.region_rect = Rect2(JACK_PADDING, visible_size)
        jack.offset.y = visible_size.y * 0.5
    return jack


func _update_cable_length(
    start_position: Vector2,
    end_position: Vector2,
    delta: float
) -> void:
    var span := start_position.distance_to(end_position)
    var required_length := span + CABLE_SLACK
    var cable_length := _segment_length * float(POINT_COUNT - 1)
    if required_length > cable_length:
        cable_length = required_length
    elif (
        tighten_below_ratio > 0.0
        and span / maxf(cable_length, 0.001) < tighten_below_ratio
    ):
        var target_length := maxf(
            MINIMUM_LENGTH,
            span / tighten_below_ratio
        )
        target_length = maxf(target_length, required_length)
        cable_length = move_toward(
            cable_length,
            target_length,
            tighten_speed * delta
        )
    
    _segment_length = cable_length / float(POINT_COUNT - 1)


func _update_jack_directions(delta: float) -> void:
    var source_sample := _positions[min(4, _positions.size() - 1)]
    var target_sample := _positions[max(0, _positions.size() - 5)]
    var response := (
        CONNECTED_JACK_DIRECTION_RESPONSE
        if state == State.CONNECTED
        else JACK_DIRECTION_RESPONSE
    )
    _source_jack_direction = _smooth_direction(
        _source_jack_direction,
        source_sample - _source_socket_position,
        delta,
        response
    )
    _target_jack_direction = _smooth_direction(
        _target_jack_direction,
        target_sample - _target_socket_position,
        delta,
        response
    )


func _smooth_direction(
    current: Vector2,
    target: Vector2,
    delta: float,
    response: float
) -> Vector2:
    if target.length_squared() <= 0.0001:
        return current
    
    var weight := 1.0 - exp(-response * delta)
    var direction := current.lerp(target.normalized(), weight)
    if direction.length_squared() <= 0.0001:
        return Vector2.DOWN
    return direction.normalized()


func _pin_endpoints(
    start_pinned: bool,
    end_pinned: bool,
    start_position: Vector2,
    end_position: Vector2
) -> void:
    if start_pinned:
        _positions[0] = start_position
        _previous_positions[0] = start_position
    if end_pinned:
        _positions[-1] = end_position
        _previous_positions[-1] = end_position


func _solve_constraints(start_pinned: bool, end_pinned: bool) -> void:
    for index: int in range(POINT_COUNT - 1):
        var next_index := index + 1
        var difference := _positions[next_index] - _positions[index]
        var distance := difference.length()
        if distance <= 0.0001:
            continue
        
        var correction := (
            difference * (distance - _segment_length) / distance
        )
        var first_pinned := index == 0 and start_pinned
        var second_pinned := (
            next_index == POINT_COUNT - 1 and end_pinned
        )
        
        if first_pinned and not second_pinned:
            _positions[next_index] -= correction
        elif second_pinned and not first_pinned:
            _positions[index] += correction
        elif not first_pinned and not second_pinned:
            _positions[index] += correction * 0.5
            _positions[next_index] -= correction * 0.5


func _update_visuals() -> void:
    _line.points = PackedVector2Array(_positions)
    if state == State.DROPPED:
        _source_socket_position = (
            _positions[0]
            - _source_jack_direction * JACK_CABLE_OFFSET
        )
        _target_socket_position = (
            _positions[-1]
            - _target_jack_direction * JACK_CABLE_OFFSET
        )
    
    _source_jack.position = _source_socket_position
    _target_jack.position = _target_socket_position
    _source_jack.rotation = _direction_rotation(_source_jack_direction)
    _target_jack.rotation = _direction_rotation(_target_jack_direction)


func _direction_rotation(direction: Vector2) -> float:
    if direction.length_squared() <= 0.0001:
        direction = Vector2.DOWN
    return Vector2.DOWN.angle_to(direction)


func _animate_jack(jack: Sprite2D) -> void:
    jack.scale = Vector2.ONE * 0.7
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(jack, "scale", Vector2.ONE, 0.15)


func _connect_port_signals() -> void:
    for port_area: ModulePortArea in [source_area, target_area]:
        if not port_area.module_port.on_connection_changed.is_connected(
            _on_port_connection_changed
        ):
            port_area.module_port.on_connection_changed.connect(
                _on_port_connection_changed
            )


func _disconnect_port_signals() -> void:
    for port_area: ModulePortArea in [source_area, target_area]:
        if (
            port_area != null
            and port_area.module_port.on_connection_changed.is_connected(
                _on_port_connection_changed
            )
        ):
            port_area.module_port.on_connection_changed.disconnect(
                _on_port_connection_changed
            )


func _on_port_connection_changed(other_port: ModulePort) -> void:
    if state == State.CONNECTED and other_port == null:
        drop()
