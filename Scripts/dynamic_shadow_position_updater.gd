@tool
class_name ModuleVisual
extends ModuleShaderRect

const NORMAL_Z_INDEX := 0
const FOREGROUND_Z_INDEX := 102
const Z_INDEX_STEP := 2

@export var powered := false
@export var unpowered_modulate := Color(0.35, 0.35, 0.35, 0.75)
@export var appearance_speed := 10.0

@export var grid_size := 8.0
@export var minimum_visible_pixels := 16.0
@export var drag_threshold := 1.5
@export var spring_strength := 1600.0
@export var spring_damping := 65.0
@export var visual_follow_speed := 60.0
@export var effect_response := 45.0
@export var effect_velocity_for_max := 800.0
@export var rotation_x_velocity_multiplier := 2.0
@export var max_tilt_degrees := 2.0
@export var max_skew_pixels := 2.0
@export var max_perspective_pixels := 3.0

var _press_pending := false
var _dragging := false
var _foreground := false
var _force_lit := false
var _press_mouse_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _desired_position := Vector2.ZERO
var _reference_position := Vector2.ZERO
var _reference_velocity := Vector2.ZERO
var _last_mouse_position := Vector2.ZERO
var _drag_velocity := Vector2.ZERO
var _effect_velocity := Vector2.ZERO
var shader_grab_uv := Vector2(0.5, 0.5)
var shader_skew := Vector2.ZERO
var shader_perspective := Vector2.ZERO
var _slide_sfx: AudioStreamPlayer
var _slide_click_sfx: AudioStreamPlayer
var _owns_slide_sfx := false
var _slide_click_distance := 0.0


func _ready() -> void:
    super._ready()
    _reference_position = global_position
    if not Engine.is_editor_hint():
        modulate = Color.WHITE if powered else unpowered_modulate
        _slide_sfx = get_tree().get_first_node_in_group(
            &"module_slide_sfx"
        ) as AudioStreamPlayer
        _slide_click_sfx = get_tree().get_first_node_in_group(
            &"module_slide_click_sfx"
        ) as AudioStreamPlayer
        _reference_position = _clamp_grid_to_viewport(
            global_position.snapped(Vector2.ONE * _grid_step())
        )
        global_position = _reference_position
    _desired_position = _reference_position
    _apply_motion_shader_params()
    update_shader_position()
    call_deferred("_update_module_render_order")


func _process(delta: float) -> void:
    if not Engine.is_editor_hint():
        _update_appearance(delta)
        _update_drag(delta)
        _update_motion(delta)
    
    super._process(delta)


func _input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    
    if event.is_action_released("Grab"):
        _end_drag()


func _gui_input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    
    if event.is_action_pressed("Grab"):
        if not _can_start_drag():
            return
        
        bring_to_foreground()
        _press_pending = true
        _press_mouse_position = get_global_mouse_position()
        _last_mouse_position = _press_mouse_position
        pivot_offset = get_local_mouse_position().clamp(Vector2.ZERO, size)
        _drag_offset = pivot_offset
        shader_grab_uv = Vector2(
            pivot_offset.x / maxf(size.x, 1.0),
            pivot_offset.y / maxf(size.y, 1.0)
        )
        _apply_motion_shader_params()
        accept_event()
    elif event.is_action_released("Grab"):
        _end_drag()
        accept_event()


func set_powered(value: bool) -> void:
    powered = value


func set_force_lit(value: bool) -> void:
    _force_lit = value


func bring_to_foreground() -> void:
    _foreground = true
    move_to_front()
    _update_module_render_order()


func _has_point(point: Vector2) -> bool:
    var global_point := get_global_transform() * point
    return _is_drag_point_allowed(global_point)


func _can_start_drag() -> bool:
    return _is_drag_point_allowed(get_global_mouse_position())


func _is_drag_point_allowed(global_point: Vector2) -> bool:
    var allowed := false
    
    for child: Node in find_children("*", "", true, false):
        if not (child is ModuleDragArea):
            continue
        
        var area := child as ModuleDragArea
        var area_point := (
            area.get_global_transform().affine_inverse() * global_point
        )
        if not area._has_point(area_point):
            continue
        
        if area.mode == ModuleDragArea.Mode.BLOCK:
            return false
        
        allowed = true
    
    return allowed


func _update_module_render_order() -> void:
    var normal_z := NORMAL_Z_INDEX
    var foreground_z := FOREGROUND_Z_INDEX
    for child: Node in get_parent().get_children():
        if not child is ModuleVisual:
            continue
        
        var module := child as ModuleVisual
        if module._foreground:
            module.z_index = foreground_z
            foreground_z += Z_INDEX_STEP
        else:
            module.z_index = normal_z
            normal_z += Z_INDEX_STEP


func _update_appearance(delta: float) -> void:
    var hovered_control := get_viewport().gui_get_hovered_control()
    var hovered := (
        hovered_control == self
        or (
            hovered_control != null
            and is_ancestor_of(hovered_control)
        )
    )
    var target := (
        Color.WHITE
        if powered or hovered or _force_lit
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
        _slide_click_distance = 0.0
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
    
    _update_slide_sfx(delta)
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
    shader_skew = -motion * max_skew_pixels
    shader_perspective = -motion * max_perspective_pixels
    
    rotation = lerp_angle(
        rotation,
        target_rotation,
        weight
    )
    _apply_motion_shader_params()


func _apply_motion_shader_params() -> void:
    set_motion_shader_params(
        shader_grab_uv,
        shader_skew,
        shader_perspective,
        Vector2.ZERO,
        size
    )


func _end_drag() -> void:
    _press_pending = false
    _dragging = false
    _drag_velocity = Vector2.ZERO
    _slide_click_distance = 0.0
    if _owns_slide_sfx:
        _slide_sfx.stop()
        _owns_slide_sfx = false


func _update_slide_sfx(delta: float) -> void:
    if _slide_sfx == null:
        return
    
    var speed_ratio := clampf(
        _drag_velocity.length() / maxf(effect_velocity_for_max, 1.0),
        0.0,
        1.0
    )
    if not _dragging or speed_ratio < 0.02:
        if _owns_slide_sfx:
            _slide_sfx.stop()
            _owns_slide_sfx = false
        return
    
    _owns_slide_sfx = true
    _slide_sfx.volume_db = lerpf(0.0, 8.0, speed_ratio)
    _slide_sfx.pitch_scale = lerpf(0.65, 0.9, speed_ratio)
    if not _slide_sfx.playing:
        _slide_sfx.play()
    
    if _slide_click_sfx == null:
        return
    
    _slide_click_distance += _drag_velocity.length() * delta
    if _slide_click_distance < 24.0:
        return
    
    _slide_click_distance = fmod(_slide_click_distance, 24.0)
    _slide_click_sfx.volume_db = lerpf(-20.0, -12.0, speed_ratio)
    _slide_click_sfx.pitch_scale = lerpf(0.5, 0.72, speed_ratio)
    _slide_click_sfx.play()


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
