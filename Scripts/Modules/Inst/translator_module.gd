class_name TranslatorModule
extends ShipModule

const FLOATING_CASETTE_SCENE := preload(
    "res://Scenes/Translator/floating_casette.tscn"
)
const EMPTY_CASETTE_TEXTURE := preload(
    "res://Assets/Modules/Translator/translator_casette_empty.png"
)
const BLANK_INNER_TEXTURE := preload(
    "res://Assets/Modules/Translator/translator_casette_blank_inner.png"
)
const BROWN_INNER_TEXTURE := preload(
    "res://Assets/Modules/Translator/translator_casette_brown_inner.png"
)
const RED_INNER_TEXTURE := preload(
    "res://Assets/Modules/Translator/translator_casette_red_inner.png"
)
const BLUE_INNER_TEXTURE := preload(
    "res://Assets/Modules/Translator/translator_casette_blue_inner.png"
)
const PURPLE_INNER_TEXTURE := preload(
    "res://Assets/Modules/Translator/translator_casette_purple_inner.png"
)
const CASETTE_LIST_BOTTOM := 68.0
const CASETTE_DRAG_BOTTOM := 104.0
const CASETTE_DRAG_HEIGHT := 14.0

@export var casette_scroll_speed := 45.0

@onready var casette_clip: Control = $"../CasetteArea/Clip"
@onready var casettes: VBoxContainer = $"../CasetteArea/Clip/Casettes"
@onready var scroll_up_enabled: TextureRect = $"../ScrollUp/Enabled"
@onready var scroll_up_disabled: TextureRect = $"../ScrollUp/Disabled"
@onready var scroll_down_enabled: TextureRect = $"../ScrollDown/Enabled"
@onready var scroll_down_disabled: TextureRect = $"../ScrollDown/Disabled"

var selected_cassette: StringName
var _scroll_direction := 0.0
var _minimum_scroll_y := 0.0
var _floating_casette: FloatingCasette
var _empty_casette_slots: Dictionary = {}


func _init() -> void:
    module_name = "Translator"
    add_input_port(&"power")
    add_output_port(&"data")


func _ready() -> void:
    super._ready()
    for child: Node in casettes.get_children():
        var casette := child as TextureRect
        if casette == null:
            continue
        
        casette.gui_input.connect(
            _on_casette_gui_input.bind(casette)
        )
    
    scroll_up_enabled.gui_input.connect(
        _on_scroll_gui_input.bind(1.0, scroll_up_enabled)
    )
    scroll_up_disabled.gui_input.connect(
        _on_scroll_gui_input.bind(1.0, scroll_up_disabled)
    )
    scroll_down_enabled.gui_input.connect(
        _on_scroll_gui_input.bind(-1.0, scroll_down_enabled)
    )
    scroll_down_disabled.gui_input.connect(
        _on_scroll_gui_input.bind(-1.0, scroll_down_disabled)
    )
    call_deferred("_refresh_casette_area")


func _process(delta: float) -> void:
    _update_scroll(delta)


func _input(event: InputEvent) -> void:
    if not event.is_action_released("Grab"):
        return
    
    _scroll_direction = 0.0


func select_cassette(cassette_id: StringName) -> void:
    selected_cassette = cassette_id


func _refresh_casette_area() -> void:
    _minimum_scroll_y = minf(
        0.0,
        casette_clip.size.y - casettes.size.y
    )
    casettes.position.y = clampf(
        casettes.position.y,
        _minimum_scroll_y,
        0.0
    )
    _update_scroll_buttons()
    _update_casette_drag_areas()


func _update_scroll(delta: float) -> void:
    if is_zero_approx(_scroll_direction):
        return
    
    var old_y := casettes.position.y
    casettes.position.y = clampf(
        old_y + _scroll_direction * casette_scroll_speed * delta,
        _minimum_scroll_y,
        0.0
    )
    if is_equal_approx(old_y, casettes.position.y):
        _scroll_direction = 0.0
    
    _update_scroll_buttons()
    _update_casette_drag_areas()


func _on_scroll_gui_input(
    event: InputEvent,
    direction: float,
    button: TextureRect
) -> void:
    if event.is_action_pressed("Grab"):
        button.accept_event()
        visual.bring_to_foreground()
        if _can_scroll(direction):
            _scroll_direction = direction
    elif event.is_action_released("Grab"):
        button.accept_event()
        _scroll_direction = 0.0


func _can_scroll(direction: float) -> bool:
    if direction > 0.0:
        return casettes.position.y < -0.01
    
    return casettes.position.y > _minimum_scroll_y + 0.01


func _update_scroll_buttons() -> void:
    var can_scroll_up := _can_scroll(1.0)
    var can_scroll_down := _can_scroll(-1.0)
    scroll_up_enabled.visible = can_scroll_up
    scroll_up_disabled.visible = not can_scroll_up
    scroll_down_enabled.visible = can_scroll_down
    scroll_down_disabled.visible = not can_scroll_down


func _update_casette_drag_areas() -> void:
    for child: Node in casettes.get_children():
        var casette := child as TextureRect
        if casette == null:
            continue
        
        var area := casette.get_child(0) as ModuleDragArea
        var list_y := casette.position.y + casettes.position.y
        if list_y >= CASETTE_LIST_BOTTOM or list_y + casette.size.y <= 0.0:
            area.mode = ModuleDragArea.Mode.ALLOW
            continue
        
        var module_position := (
            visual.get_global_transform().affine_inverse()
            * (casette.get_global_transform() * Vector2.ZERO)
        )
        var height := minf(
            CASETTE_DRAG_HEIGHT,
            CASETTE_DRAG_BOTTOM - module_position.y
        )
        if height <= 0.0:
            area.mode = ModuleDragArea.Mode.ALLOW
            continue
        
        area.mode = ModuleDragArea.Mode.BLOCK
        area.size.y = height


func _on_casette_gui_input(
    event: InputEvent,
    casette: TextureRect
) -> void:
    if not event.is_action_pressed("Grab"):
        return
    
    var area := casette.get_child(0) as ModuleDragArea
    if area.mode == ModuleDragArea.Mode.ALLOW:
        return
    
    casette.accept_event()
    visual.bring_to_foreground()
    if (
        _floating_casette != null
        or _empty_casette_slots.has(casette)
        or not _casette_is_visible(casette)
    ):
        return
    
    _pick_up_casette(casette)


func _casette_is_visible(casette: TextureRect) -> bool:
    var list_y := casette.position.y + casettes.position.y
    return list_y < CASETTE_LIST_BOTTOM and list_y + casette.size.y > 0.0


func _pick_up_casette(casette: TextureRect) -> void:
    var source_texture := casette.texture
    _empty_casette_slots[casette] = true
    casette.texture = EMPTY_CASETTE_TEXTURE
    
    _floating_casette = (
        FLOATING_CASETTE_SCENE.instantiate() as FloatingCasette
    )
    var floating_texture := (
        _floating_casette.get_node("TextureRect") as TextureRect
    )
    floating_texture.texture = _inner_texture_for(casette)
    var spawn_position := casette.global_position + Vector2(13.0, -8.0)
    _floating_casette.position = (
        visual.get_global_transform().affine_inverse() * spawn_position
    )
    _floating_casette.rotation = (
        -PI * 0.5
        - visual.get_global_transform().get_rotation()
    )
    _floating_casette.fell_offscreen.connect(
        _on_floating_casette_fell.bind(
            _floating_casette,
            casette,
            source_texture
        )
    )
    _floating_casette.released.connect(
        _on_floating_casette_released.bind(_floating_casette)
    )
    visual.add_child(_floating_casette)
    _floating_casette.grab()


func _inner_texture_for(casette: TextureRect) -> Texture2D:
    match casette.name:
        &"BrownCasette":
            return BROWN_INNER_TEXTURE
        &"RedCasette":
            return RED_INNER_TEXTURE
        &"BlueCasette":
            return BLUE_INNER_TEXTURE
        &"PurpleCasette":
            return PURPLE_INNER_TEXTURE
        _:
            return BLANK_INNER_TEXTURE


func _on_floating_casette_fell(
    floating: FloatingCasette,
    source: TextureRect,
    source_texture: Texture2D
) -> void:
    if is_instance_valid(source):
        source.texture = source_texture
        source.pivot_offset = source.size * 0.5
        source.scale = Vector2.ZERO
        source.create_tween().set_trans(Tween.TRANS_BACK).set_ease(
            Tween.EASE_OUT
        ).tween_property(source, "scale", Vector2.ONE, 0.2)
        _empty_casette_slots.erase(source)
    if _floating_casette == floating:
        _floating_casette = null


func _on_floating_casette_released(
    floating: FloatingCasette
) -> void:
    if _floating_casette == floating:
        _floating_casette = null


func process_input(_port_name: StringName, data: Dictionary) -> void:
    var output_data := data.duplicate(true)
    
    if not output_data.has("comms"):
        send_data(&"data", output_data)
        return
    
    var comms: Dictionary = output_data["comms"]
    var race := comms["race"] as AlienRaceData
    
    comms["stage"] = &"translated"
    
    if race != null and selected_cassette == race.cassette_id:
        comms["translated_text"] = _translate(comms)
    else:
        comms["translated_text"] = comms.get("decoded_text", "")
    
    comms["display_text"] = comms["translated_text"]
    send_data(&"data", output_data)


func _translate(comms: Dictionary) -> String:
    var original_text: String = comms["original_text"]
    var receive_start := float(comms["receive_start_ratio"])
    var transmission_progress := float(comms["transmission_progress"])
    var decode_progress := float(comms["decode_progress"])
    var decode_accuracy := float(comms["decode_accuracy"])
    var visible_progress := minf(transmission_progress, decode_progress)
    var start := floori(original_text.length() * receive_start)
    var end := floori(original_text.length() * visible_progress)
    var result := ""
    var random := RandomNumberGenerator.new()
    random.seed = hash(comms["message_id"])
    
    for index in range(end):
        var character := original_text.substr(index, 1)
        
        if index < start:
            result += " " if character == " " else "?"
        elif (
            decode_accuracy < 0.9
            and character != " "
            and random.randf() > decode_accuracy
        ):
            result += "#"
        else:
            result += character
    
    return result
