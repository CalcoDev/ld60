@tool
extends TextureRect

@onready var move: ColorRect = $Move

@export var fill: float = 0.0:
    set(value):
        fill = value
        if move != null:
            var offset := fill * 108
            move.size.x = 108 - offset
            move.position.x = offset
