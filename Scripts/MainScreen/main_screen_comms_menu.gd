class_name MainScreenCommsMenu
extends Control

@onready var title_label: Label = $ScreenMask/Title
@onready var text_label: Label = $ScreenMask/AsciiTextShowcase
@onready var loader = $ScreenMask/Loader

var _comms: Dictionary = {}
var _default_font: Font


func _ready() -> void:
    text_label.label_settings = text_label.label_settings.duplicate()
    _default_font = text_label.label_settings.font
    _render()


func set_comms(comms: Dictionary) -> void:
    _comms = comms.duplicate(true)
    if is_node_ready():
        _render()


func _render() -> void:
    if _comms.is_empty():
        title_label.text = "COMMS"
        text_label.text = ""
        loader.fill = 0.0
        return
    
    var stage: StringName = _comms.get("stage", &"received")
    title_label.text = "COMMS // %s" % String(stage).to_upper()
    text_label.text = _comms.get("display_text", "")
    loader.fill = float(_comms.get("transmission_progress", 0.0))
    text_label.label_settings.font = _default_font
    
    var glyph_fonts: Array = _comms.get("glyph_fonts", [])
    if stage == &"received" and not glyph_fonts.is_empty():
        text_label.label_settings.font = glyph_fonts[0] as Font
