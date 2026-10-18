@tool
class_name ModuleShaderRect
extends TextureRect

@export var logical_screen_size := Vector2(640.0, 360.0)
@export var use_runtime_viewport_size := false
@export var shader_material_preset: ShaderMaterial = preload(
    "res://Resources/Materials/module_visual_material.tres"
)

var shader_material: ShaderMaterial


func _ready() -> void:
    var source := material as ShaderMaterial
    if source == null:
        source = shader_material_preset
    if Engine.is_editor_hint() and material is ShaderMaterial:
        shader_material = material as ShaderMaterial
    else:
        set_shader_material(source)
    set_process(true)
    update_shader_position()


func _process(_delta: float) -> void:
    update_shader_position()


func set_shader_material(source: ShaderMaterial) -> void:
    if source == null:
        shader_material = null
        material = null
        return
    
    shader_material = source.duplicate() as ShaderMaterial
    material = shader_material


func set_motion_shader_params(
    grab_uv: Vector2,
    skew: Vector2,
    perspective: Vector2,
    vertex_origin: Vector2,
    module_size: Vector2
) -> void:
    if shader_material == null:
        return
    
    shader_material.set_shader_parameter("drag_grab_uv", grab_uv)
    shader_material.set_shader_parameter("drag_skew", skew)
    shader_material.set_shader_parameter(
        "drag_perspective",
        perspective
    )
    shader_material.set_shader_parameter(
        "drag_vertex_origin",
        vertex_origin
    )
    shader_material.set_shader_parameter(
        "drag_module_size",
        module_size
    )


func update_shader_position() -> void:
    if shader_material == null:
        return
    
    var screen_size := get_shader_screen_size()
    if screen_size.x <= 0.0 or screen_size.y <= 0.0:
        return
    
    var transform := get_global_transform()
    var center := transform * (size * 0.5)
    var box_size := Vector2(
        abs(transform.x.x) * size.x + abs(transform.y.x) * size.y,
        abs(transform.x.y) * size.x + abs(transform.y.y) * size.y
    )
    
    shader_material.set_shader_parameter(
        "screen_center_uv",
        center / screen_size
    )
    shader_material.set_shader_parameter(
        "object_size_uv",
        box_size / screen_size
    )


func get_shader_screen_size() -> Vector2:
    if use_runtime_viewport_size and not Engine.is_editor_hint():
        return get_viewport_rect().size
    
    return logical_screen_size
