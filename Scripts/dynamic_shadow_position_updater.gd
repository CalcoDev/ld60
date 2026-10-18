@tool
class_name ModuleVisual
extends TextureRect

# (for accurate preview in editor)
@export var logical_screen_size := Vector2(640.0, 360.0)

# Optionally use the actual viewport size when running.
@export var use_runtime_viewport_size := false

@export var powered := false
@export var unpowered_modulate := Color(0.35, 0.35, 0.35, 0.75)
@export var appearance_speed := 10.0

@export var grid_size := 8.0
@export var minimum_visible_pixels := 16.0
@export var drag_threshold := 3.0
@export var spring_strength := 1600.0
@export var spring_damping := 65.0
@export var visual_follow_speed := 60.0
@export var effect_response := 45.0
@export var effect_velocity_for_max := 800.0
@export var rotation_x_velocity_multiplier := 2.0
@export var max_tilt_degrees := 2.0
@export var max_skew_pixels := 2.0
@export var max_perspective_pixels := 3.0

var _shadow_material: ShaderMaterial
var _press_pending := false
var _dragging := false
var _press_mouse_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _desired_position := Vector2.ZERO
var _reference_position := Vector2.ZERO
var _reference_velocity := Vector2.ZERO
var _last_mouse_position := Vector2.ZERO
var _drag_velocity := Vector2.ZERO
var _effect_velocity := Vector2.ZERO
var _grab_uv := Vector2(0.5, 0.5)


func _ready() -> void:
    if material is ShaderMaterial:
        _shadow_material = (
            material as ShaderMaterial
        ).duplicate() as ShaderMaterial

        material = _shadow_material

    set_process(true)
    pivot_offset = size * 0.5
    _reference_position = global_position
    if not Engine.is_editor_hint():
        _reference_position = _clamp_grid_to_viewport(
            global_position.snapped(Vector2.ONE * _grid_step())
        )
        global_position = _reference_position
    _desired_position = _reference_position
    if _shadow_material != null:
        _shadow_material.set_shader_parameter(
            "drag_grab_uv",
            _grab_uv
        )
    _update_shadow_position()


func _process(delta: float) -> void:
    if not Engine.is_editor_hint():
        _update_appearance(delta)
        _update_drag(delta)
        _update_motion(delta)
    
    _update_shadow_position()


func _input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    
    if event.is_action_released("Grab"):
        _end_drag()


func _gui_input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    
    if event.is_action_pressed("Grab"):
        _press_pending = true
        _press_mouse_position = get_global_mouse_position()
        _last_mouse_position = _press_mouse_position
        pivot_offset = get_local_mouse_position().clamp(Vector2.ZERO, size)
        _drag_offset = pivot_offset
        _grab_uv = Vector2(
            pivot_offset.x / maxf(size.x, 1.0),
            pivot_offset.y / maxf(size.y, 1.0)
        )
        if _shadow_material != null:
            _shadow_material.set_shader_parameter(
                "drag_grab_uv",
                _grab_uv
            )
        accept_event()
    elif event.is_action_released("Grab"):
        _end_drag()
        accept_event()


func set_powered(value: bool) -> void:
    powered = value


func _update_appearance(delta: float) -> void:
    var hovered := Rect2(Vector2.ZERO, size).has_point(
        get_local_mouse_position()
    )
    var target := (
        Color.WHITE
        if powered or hovered
        else unpowered_modulate
    )
    var weight := 1.0 - exp(-appearance_speed * delta)
    modulate = modulate.lerp(target, weight)


func _update_drag(delta: float) -> void:
    if _press_pending and not Input.is_action_pressed("Grab"):
        _end_drag()
        return
    
    var mouse_position := get_global_mouse_position()
    
    if (
        _press_pending
        and mouse_position.distance_to(_press_mouse_position)
        >= drag_threshold
    ):
        _press_pending = false
        _dragging = true
        move_to_front()
    elif _press_pending:
        _last_mouse_position = mouse_position
    
    if _dragging:
        if delta > 0.0:
            _drag_velocity = (
                mouse_position - _last_mouse_position
            ) / delta
        _last_mouse_position = mouse_position
        _desired_position = _clamp_to_viewport(
            mouse_position - _drag_offset
        )
    
    _update_positions(delta)


func _update_motion(delta: float) -> void:
    var target_velocity := _drag_velocity if _dragging else Vector2.ZERO
    var weight := 1.0 - exp(-effect_response * delta)
    _effect_velocity = _effect_velocity.lerp(target_velocity, weight)
    var motion := _effect_velocity / maxf(effect_velocity_for_max, 1.0)
    if motion.length_squared() > 1.0:
        motion = motion.normalized()
    
    var rotation_amount := clampf(
        motion.x * rotation_x_velocity_multiplier,
        -1.0,
        1.0
    )
    var target_rotation := deg_to_rad(
        rotation_amount * max_tilt_degrees
    )
    var target_skew := -motion * max_skew_pixels
    var target_perspective := -motion * max_perspective_pixels
    
    rotation = lerp_angle(
        rotation,
        target_rotation,
        weight
    )
    if _shadow_material != null:
        _shadow_material.set_shader_parameter("drag_skew", target_skew)
        _shadow_material.set_shader_parameter(
            "drag_perspective",
            target_perspective
        )


func _end_drag() -> void:
    _press_pending = false
    _dragging = false
    _drag_velocity = Vector2.ZERO


func _update_positions(delta: float) -> void:
    _reference_velocity += (
        _desired_position - _reference_position
    ) * spring_strength * delta
    _reference_velocity *= exp(-spring_damping * delta)
    var next_reference := (
        _reference_position + _reference_velocity * delta
    )
    var clamped_reference := _clamp_to_viewport(next_reference)
    
    if not is_equal_approx(next_reference.x, clamped_reference.x):
        _reference_velocity.x = 0.0
    if not is_equal_approx(next_reference.y, clamped_reference.y):
        _reference_velocity.y = 0.0
    
    _reference_position = clamped_reference
    var snapped_position := _clamp_grid_to_viewport(
        _reference_position.snapped(Vector2.ONE * _grid_step())
    )
    var weight := 1.0 - exp(-visual_follow_speed * delta)
    global_position = global_position.lerp(snapped_position, weight)


func _clamp_to_viewport(target_position: Vector2) -> Vector2:
    var viewport_size := get_viewport_rect().size
    var minimum_position := -size + Vector2.ONE * minimum_visible_pixels
    var maximum_position := viewport_size - Vector2.ONE * minimum_visible_pixels
    
    return target_position.clamp(minimum_position, maximum_position)


func _clamp_grid_to_viewport(target_position: Vector2) -> Vector2:
    var viewport_size := get_viewport_rect().size
    var minimum_position := -size + Vector2.ONE * minimum_visible_pixels
    var maximum_position := viewport_size - Vector2.ONE * minimum_visible_pixels
    var step := _grid_step()
    var grid_minimum := Vector2(
        ceilf(minimum_position.x / step) * step,
        ceilf(minimum_position.y / step) * step
    )
    var grid_maximum := Vector2(
        floorf(maximum_position.x / step) * step,
        floorf(maximum_position.y / step) * step
    )
    
    return target_position.clamp(grid_minimum, grid_maximum)


func _grid_step() -> float:
    return maxf(grid_size, 1.0)


func _update_shadow_position() -> void:
    if _shadow_material == null:
        return

    var screen_size := logical_screen_size

    if use_runtime_viewport_size and not Engine.is_editor_hint():
        screen_size = get_viewport_rect().size

    if screen_size.x <= 0.0 or screen_size.y <= 0.0:
        return

    # Global transform includes parent transforms.
    # This also handles scaled controls.
    var xf := get_global_transform()

    var center := xf * (size * 0.5)

    # Axis-aligned bounding size in global coordinates.
    var box_size := Vector2(
        abs(xf.x.x) * size.x + abs(xf.y.x) * size.y,
        abs(xf.x.y) * size.x + abs(xf.y.y) * size.y
    )

    _shadow_material.set_shader_parameter(
        "screen_center_uv",
        center / screen_size
    )

    _shadow_material.set_shader_parameter(
        "object_size_uv",
        box_size / screen_size
    )
