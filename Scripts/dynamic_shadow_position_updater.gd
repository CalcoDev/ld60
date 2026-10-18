@tool
extends TextureRect

# Logical dimensions of the game.
# Used in the editor for accurate previews.
@export var logical_screen_size := Vector2(640.0, 320.0)

# Optionally use the actual viewport size when running.
@export var use_runtime_viewport_size := false

var _shadow_material: ShaderMaterial


func _ready() -> void:
    # Each draggable box needs its own shader parameters.
    # Otherwise, multiple boxes sharing the material
    # would overwrite each other's positions.
    if material is ShaderMaterial:
        _shadow_material = (
            material as ShaderMaterial
        ).duplicate() as ShaderMaterial

        material = _shadow_material

    set_process(true)
    _update_shadow_position()


func _process(_delta: float) -> void:
    _update_shadow_position()


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
