@tool
class_name ModuleAttachmentVisual
extends ModuleShaderRect

var module_visual: ModuleVisual


func _ready() -> void:
    super._ready()
    show_behind_parent = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    call_deferred("_setup_module_visual")


func _process(_delta: float) -> void:
    if module_visual != null:
        var module_inverse := (
            module_visual.get_global_transform().affine_inverse()
        )
        var local_origin := (
            module_inverse * (get_global_transform() * Vector2.ZERO)
        )
        set_motion_shader_params(
            module_visual.shader_grab_uv,
            module_visual.shader_skew,
            module_visual.shader_perspective,
            local_origin,
            module_visual.size
        )
    
    super._process(_delta)


func _setup_module_visual() -> void:
    module_visual = _find_module_visual()
    if module_visual == null:
        push_error("Module attachment must be a child of a ModuleVisual.")
        return
    
    if not Engine.is_editor_hint():
        set_shader_material(module_visual.shader_material)
    update_shader_position()


func _find_module_visual() -> ModuleVisual:
    var current := get_parent()
    while current != null:
        if current is ModuleVisual:
            return current
        current = current.get_parent()
    
    return null


func get_shader_screen_size() -> Vector2:
    if module_visual != null:
        return module_visual.get_shader_screen_size()
    
    return super.get_shader_screen_size()
