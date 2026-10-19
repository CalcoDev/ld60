@tool
class_name ModulePortArea
extends Control

enum HitShape {
    RECTANGLE,
    CIRCLE,
}

@export var port_name: StringName
@export var hit_shape := HitShape.RECTANGLE:
    set(value):
        hit_shape = value
        queue_redraw()
@export var editor_debug_color := Color(0.2, 0.9, 1.0, 0.25):
    set(value):
        editor_debug_color = value
        queue_redraw()
@export var editor_debug_width := 0.75:
    set(value):
        editor_debug_width = value
        queue_redraw()

var module_port: ModulePort
var module_visual: ModuleVisual
var ship_module: ShipModule


func _ready() -> void:
    queue_redraw()
    if not Engine.is_editor_hint():
        call_deferred("_bind_port")


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()


func _draw() -> void:
    if not Engine.is_editor_hint():
        return
    
    var half_width := editor_debug_width * 0.5
    if hit_shape == HitShape.CIRCLE:
        draw_arc(
            size * 0.5,
            maxf(minf(size.x, size.y) * 0.5 - half_width, 0.0),
            0.0,
            TAU,
            32,
            editor_debug_color,
            editor_debug_width,
            true
        )
        return
    
    draw_rect(
        Rect2(
            Vector2.ONE * half_width,
            size - Vector2.ONE * editor_debug_width
        ),
        editor_debug_color,
        false,
        editor_debug_width
    )


func _has_point(point: Vector2) -> bool:
    if hit_shape == HitShape.CIRCLE:
        var radius := minf(size.x, size.y) * 0.5
        return point.distance_squared_to(size * 0.5) <= radius * radius
    
    return Rect2(Vector2.ZERO, size).has_point(point)


func _gui_input(event: InputEvent) -> void:
    if event.is_action_pressed("Grab"):
        if module_visual != null:
            module_visual.bring_to_foreground()
        var wire_manager := get_tree().get_first_node_in_group(
            &"wire_manager"
        ) as WireManager
        if wire_manager != null:
            wire_manager.begin_wire(self)
        accept_event()
    elif event.is_action_released("Grab"):
        accept_event()


func _bind_port() -> void:
    module_visual = _find_module_visual()
    if module_visual == null:
        push_error("Port area must be a child of a ModuleVisual.")
        return
    
    for child: Node in module_visual.get_children():
        if child is ShipModule:
            ship_module = child
            break
    
    if ship_module == null:
        push_error("Port area could not find its ShipModule.")
        return
    
    module_port = ship_module.get_input_port(port_name)
    if module_port == null:
        module_port = ship_module.get_output_port(port_name)
    
    if module_port == null:
        push_error(
            "%s has no port named %s."
            % [ship_module.module_name, port_name]
        )


func _find_module_visual() -> ModuleVisual:
    var current := get_parent()
    while current != null:
        if current is ModuleVisual:
            return current
        current = current.get_parent()
    
    return null


func get_wire_anchor_position() -> Vector2:
    return get_global_transform() * (size * 0.5)
