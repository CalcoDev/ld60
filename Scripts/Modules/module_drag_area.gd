@tool
class_name ModuleDragArea
extends Control

enum Mode {
    ALLOW,
    BLOCK,
}

enum HitShape {
    RECTANGLE,
    CIRCLE,
}

@export var mode := Mode.ALLOW:
    set(value):
        mode = value
        queue_redraw()
@export var hit_shape := HitShape.RECTANGLE:
    set(value):
        hit_shape = value
        queue_redraw()
@export var editor_debug_width := 1.0:
    set(value):
        editor_debug_width = value
        queue_redraw()


func _ready() -> void:
    queue_redraw()


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()


func _draw() -> void:
    if not Engine.is_editor_hint():
        return
    
    var color := (
        Color(0.25, 1.0, 0.35, 0.9)
        if mode == Mode.ALLOW
        else Color(1.0, 0.2, 0.2, 0.9)
    )
    var half_width := editor_debug_width * 0.5
    if hit_shape == HitShape.CIRCLE:
        draw_arc(
            size * 0.5,
            maxf(minf(size.x, size.y) * 0.5 - half_width, 0.0),
            0.0,
            TAU,
            32,
            color,
            editor_debug_width,
            true
        )
        return
    
    draw_rect(
        Rect2(
            Vector2.ONE * half_width,
            size - Vector2.ONE * editor_debug_width
        ),
        color,
        false,
        editor_debug_width
    )


func _has_point(point: Vector2) -> bool:
    if hit_shape == HitShape.CIRCLE:
        var radius := minf(size.x, size.y) * 0.5
        return point.distance_squared_to(size * 0.5) <= radius * radius
    
    return Rect2(Vector2.ZERO, size).has_point(point)


func contains_mouse_position() -> bool:
    return _has_point(get_local_mouse_position())
