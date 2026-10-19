class_name ManualLayer
extends CanvasLayer

signal page_selected(page_name: String)

@export var slide_duration := 0.3
@export var fade_duration := 0.2
@export var open_pages_y := 0.0

@onready var source_manual: ModuleVisual = $"../GameLayer/Boxes/Manual"
@onready var screen: Control = $SCREEN
@onready var backdrop: ColorRect = $SCREEN/ColorRect
@onready var pages: TextureRect = $SCREEN/Manual

var current_page := ""
var _animation: Tween
var _open_pages_position := Vector2.ZERO


func _ready() -> void:
    _open_pages_position = Vector2(pages.position.x, open_pages_y)
    for child: Node in source_manual.get_children():
        if child is ManualFolder:
            (child as ManualFolder).page_pressed.connect(open_page)


func _input(event: InputEvent) -> void:
    if visible and event.is_action_pressed(&"ui_cancel"):
        close()
        get_viewport().set_input_as_handled()


func open_page(page_name: String) -> void:
    current_page = page_name
    page_selected.emit(current_page)
    _stop_animation()
    backdrop.modulate.a = 0.0
    pages.position.y = screen.size.y
    visible = true
    
    _animation = create_tween()
    _animation.tween_property(
        pages,
        "position",
        _open_pages_position,
        slide_duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _animation.parallel()
    _animation.tween_property(
        backdrop,
        "modulate:a",
        1.0,
        fade_duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close() -> void:
    if not visible:
        return
    
    _stop_animation()
    _animation = create_tween()
    _animation.tween_property(
        backdrop,
        "modulate:a",
        0.0,
        fade_duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _animation.parallel()
    _animation.tween_property(
        pages,
        "position:y",
        screen.size.y,
        slide_duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _animation.finished.connect(_finish_close)


func _stop_animation() -> void:
    if _animation != null:
        _animation.kill()


func _finish_close() -> void:
    visible = false
