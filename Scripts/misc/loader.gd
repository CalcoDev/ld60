@tool
extends TextureRect

@onready var move: ColorRect = $Move

var _full_width := 0.0
var _start_x := 0.0

@export var fill: float = 0.0:
    set(value):
        fill = clampf(value, 0.0, 1.0)
        _update_fill()


func _ready() -> void:
    _full_width = move.size.x
    _start_x = move.position.x
    _update_fill()


func _update_fill() -> void:
    if move == null or _full_width <= 0.0:
        return
    
    var offset := fill * _full_width
    move.size.x = _full_width - offset
    move.position.x = _start_x + offset
