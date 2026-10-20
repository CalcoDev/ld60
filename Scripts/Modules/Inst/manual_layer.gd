class_name ManualLayer
extends CanvasLayer

signal page_selected(page_name: String)

const PAGE_PLANETS: Dictionary[StringName, StringName] = {
    &"blue": &"blue_planet",
    &"red": &"red_planet",
    &"purple": &"purple_planet",
    &"brown": &"orange_planet",
}

@export var slide_duration := 0.3
@export var fade_duration := 0.2
@export var open_pages_y := 0.0
@export var page_collections: Dictionary[StringName, Texture2D] = {}
@export var unknown_collection: Texture2D

@onready var source_manual: ModuleVisual = $"../GameLayer/Boxes/Manual"
@onready var screen: Control = $SCREEN
@onready var backdrop: ColorRect = $SCREEN/ColorRect
@onready var pages: TextureRect = $SCREEN/Manual
@onready var page_turn_left: TextureRect = $SCREEN/Manual/FlipPageLeft
@onready var page_turn_right: TextureRect = $SCREEN/Manual/FlipPageRight
@onready var page_flip: AnimatedSprite2D = $SCREEN/Manual/PageFlip
@onready var page_turn_sfx: AudioStreamPlayer = $PageTurnSfx

var current_page := ""
var page_index := 0
var _page_sheet: Texture2D
var _page_count := 0
var _page_texture := AtlasTexture.new()
var _pending_page_index := -1
var _animation: Tween
var _open_pages_position := Vector2.ZERO


func _ready() -> void:
    _open_pages_position = Vector2(pages.position.x, open_pages_y)
    for child: Node in source_manual.get_children():
        if child is ManualFolder:
            (child as ManualFolder).page_pressed.connect(open_page)
    page_turn_left.gui_input.connect(_on_page_turn_input.bind(-1))
    page_turn_right.gui_input.connect(_on_page_turn_input.bind(1))
    page_flip.frame_changed.connect(_on_page_flip_frame_changed)
    page_flip.animation_finished.connect(_on_page_flip_finished)
    _update_page()


func _input(event: InputEvent) -> void:
    if visible and event.is_action_pressed(&"ui_cancel"):
        close()
        get_viewport().set_input_as_handled()


func open_page(page_name: String) -> void:
    current_page = page_name
    page_index = 0
    _page_sheet = _get_page_collection(StringName(page_name))
    _page_count = (
        floori(_page_sheet.get_width() / pages.size.x)
        if _page_sheet != null and pages.size.x > 0.0
        else 0
    )
    _update_page()
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


func _get_page_collection(page_name: StringName) -> Texture2D:
    var planet_id: StringName = PAGE_PLANETS.get(page_name, &"")
    if not planet_id.is_empty() and unknown_collection != null:
        var simulation := Globals.ship_simulation
        if (
            simulation == null
            or not simulation.has_discovered_object(planet_id)
        ):
            return unknown_collection
    
    return page_collections.get(page_name) as Texture2D


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


func _on_page_turn_input(event: InputEvent, direction: int) -> void:
    if not event.is_action_pressed("Grab") or page_flip.visible:
        return
    
    var next_page := page_index + direction
    if next_page < 0 or next_page >= _page_count:
        return
    
    _pending_page_index = next_page
    page_flip.stop()
    page_flip.animation = &"left" if direction < 0 else &"right"
    page_flip.frame = 0
    page_flip.frame_progress = 0.0
    page_flip.visible = true
    page_flip.play()
    page_turn_left.visible = false
    page_turn_right.visible = false
    page_turn_sfx.play()
    (page_turn_left if direction < 0 else page_turn_right).accept_event()


func _on_page_flip_frame_changed() -> void:
    if _pending_page_index < 0:
        return
    
    var frame_count := page_flip.sprite_frames.get_frame_count(
        page_flip.animation
    )
    if page_flip.frame < frame_count / 2:
        return
    
    page_index = _pending_page_index
    _pending_page_index = -1
    _update_page()
    page_turn_left.visible = false
    page_turn_right.visible = false


func _on_page_flip_finished() -> void:
    page_flip.visible = false
    _pending_page_index = -1
    _update_page()


func _update_page() -> void:
    if _page_sheet == null or _page_count == 0:
        pages.texture = null
        page_turn_left.visible = false
        page_turn_right.visible = false
        return
    
    page_index = clampi(page_index, 0, _page_count - 1)
    _page_texture.atlas = _page_sheet
    _page_texture.region = Rect2(
        Vector2(page_index * pages.size.x, 0.0),
        pages.size
    )
    pages.texture = _page_texture
    page_turn_left.visible = page_index > 0
    page_turn_right.visible = page_index < _page_count - 1


func _stop_animation() -> void:
    if _animation != null:
        _animation.kill()


func _finish_close() -> void:
    visible = false
