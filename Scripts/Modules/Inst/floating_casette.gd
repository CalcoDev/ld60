class_name FloatingCasette
extends Control

signal fell_offscreen
signal released

const FOLLOW_SPEED := 35.0
const SEGMENT_LENGTH := 72.0
const HELD_GRAVITY := 10000.0
const FALL_GRAVITY := 2000.0
const DAMPING := 0.98

var _held := true
var _top := Vector2.ZERO
var _previous_top := Vector2.ZERO
var _bottom := Vector2.ZERO
var _previous_bottom := Vector2.ZERO
var _fall_velocity := Vector2.ZERO
var _angular_velocity := 0.0
var _segment_angle := 0.0
var _last_delta := 1.0 / 60.0


func grab() -> void:
    _held = true
    _top = global_position
    _previous_top = _top
    var direction := Vector2.DOWN.rotated(
        get_global_transform().get_rotation()
    )
    _bottom = _top + direction * SEGMENT_LENGTH
    _previous_bottom = _bottom
    _fall_velocity = Vector2.ZERO
    _angular_velocity = 0.0
    _segment_angle = direction.angle()


func _process(delta: float) -> void:
    _last_delta = delta
    if _held:
        _update_held(delta)
    else:
        _update_falling(delta)
    
    global_position = _top
    _set_global_rotation((_bottom - _top).angle() - PI * 0.5)
    if (
        not _held
        and minf(_top.y, _bottom.y)
        > get_viewport_rect().size.y + 10.0
    ):
        fell_offscreen.emit()
        queue_free()


func _input(event: InputEvent) -> void:
    if _held and event.is_action_released("Grab"):
        _release()


func _update_held(delta: float) -> void:
    var old_top := _top
    var follow_weight := 1.0 - exp(-FOLLOW_SPEED * delta)
    _top = _top.lerp(get_global_mouse_position(), follow_weight)
    _previous_top = old_top
    
    var velocity := (_bottom - _previous_bottom) * DAMPING
    _previous_bottom = _bottom
    _bottom += velocity + Vector2.DOWN * HELD_GRAVITY * delta * delta
    _bottom = _top + _segment_direction() * SEGMENT_LENGTH


func _update_falling(delta: float) -> void:
    var center := (_top + _bottom) * 0.5
    _fall_velocity.y += FALL_GRAVITY * delta
    center += _fall_velocity * delta
    _segment_angle += _angular_velocity * delta
    var half_segment := (
        Vector2.RIGHT.rotated(_segment_angle)
        * SEGMENT_LENGTH * 0.5
    )
    _top = center - half_segment
    _bottom = center + half_segment


func _release() -> void:
    var frame_time := maxf(_last_delta, 0.001)
    var center := (_top + _bottom) * 0.5
    var previous_center := (
        _previous_top + _previous_bottom
    ) * 0.5
    _fall_velocity = (center - previous_center) / frame_time
    _segment_angle = (_bottom - _top).angle()
    var previous_segment := _previous_bottom - _previous_top
    if not previous_segment.is_zero_approx():
        _angular_velocity = angle_difference(
            previous_segment.angle(),
            _segment_angle
        ) / frame_time
    _angular_velocity = clampf(_angular_velocity, -20.0, 20.0)
    _held = false
    released.emit()


func _segment_direction() -> Vector2:
    var segment := _bottom - _top
    return Vector2.DOWN if segment.is_zero_approx() else segment.normalized()


func _set_global_rotation(value: float) -> void:
    var parent := get_parent() as CanvasItem
    var parent_rotation := 0.0
    if parent != null:
        parent_rotation = parent.get_global_transform().get_rotation()
    rotation = value - parent_rotation
