class_name ManualFolder
extends TextureRect

signal page_pressed(page_name: String)

@export_range(0.0, 1.0) var alpha_threshold := 0.1
@export var rise_distance := 30.0
@export var hover_duration := 0.2
@export var idle_color := Color("888888")
@export var hover_color := Color.WHITE
@export var page_name := ""

var _image: Image
var _rest_position := Vector2.ZERO
var _hover_tween: Tween
var _hovered := false

@onready var movement_sfx: AudioStreamPlayer = $"../FolderSfx"


func _ready() -> void:
    _image = texture.get_image()
    _rest_position = position
    mouse_entered.connect(_set_hovered.bind(true))
    mouse_exited.connect(_set_hovered.bind(false))


func _has_point(point: Vector2) -> bool:
    return (
        _is_opaque_at(point)
        or _is_opaque_at(point + position - _rest_position)
    )


func _gui_input(event: InputEvent) -> void:
    if not event.is_action_pressed("Grab"):
        return
    
    page_pressed.emit(page_name)
    accept_event()


func _is_opaque_at(point: Vector2) -> bool:
    if (
        _image == null
        or size.x <= 0.0
        or size.y <= 0.0
        or not Rect2(Vector2.ZERO, size).has_point(point)
    ):
        return false
    
    var uv := point / size
    var pixel := Vector2i(
        clampi(
            floori(uv.x * _image.get_width()),
            0,
            _image.get_width() - 1
        ),
        clampi(
            floori(uv.y * _image.get_height()),
            0,
            _image.get_height() - 1
        )
    )
    return _image.get_pixelv(pixel).a >= alpha_threshold


func _set_hovered(hovered: bool) -> void:
    if hovered == _hovered:
        return
    
    _hovered = hovered
    movement_sfx.play()
    if _hover_tween != null:
        _hover_tween.kill()
    
    var target_position := _rest_position
    if hovered:
        target_position.y -= rise_distance
    
    _hover_tween = create_tween().set_parallel()
    _hover_tween.set_trans(Tween.TRANS_QUAD)
    _hover_tween.set_ease(Tween.EASE_OUT)
    _hover_tween.tween_property(
        self,
        "position",
        target_position,
        hover_duration
    )
    _hover_tween.tween_property(
        self,
        "self_modulate",
        hover_color if hovered else idle_color,
        hover_duration
    )
