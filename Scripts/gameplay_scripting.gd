extends Node

@onready var simulation: ShipSimulation = $"../ShipSimulation"
@onready var thruster: ThrusterModule = (
    $"../GameLayer/Boxes/Thruster/ThrusterLogic"
)
@onready var rotator: RotatorModule = (
    $"../GameLayer/Boxes/Rotator/RotatorLogic"
)
@onready var comms_in: CommsInModule = (
    $"../GameLayer/Boxes/CommsIn/CommsInLogic"
)

var dialogues := GameDialogues.new()


func _ready() -> void:
    add_child(dialogues)
    simulation.object_reached.connect(_on_object_reached)
    simulation.object_left.connect(_on_object_left)
    simulation.map_edge_reached.connect(_on_map_edge_reached)


func _on_object_reached(object_id: StringName) -> void:
    thruster.reset_thrust()
    rotator.reset_rotation()
    match object_id:
        &"blue_planet":
            _blue_planet_event()
        &"red_planet":
            _red_planet_event()
        &"purple_planet":
            _purple_planet_event()
        &"orange_planet":
            _orange_planet_event()


func _on_object_left(object_id: StringName) -> void:
    match object_id:
        &"blue_planet":
            dialogues.blue_planet_outro(comms_in)
        &"purple_planet":
            dialogues.purple_planet_outro(comms_in)


func _on_map_edge_reached(side: StringName) -> void:
    thruster.reset_thrust()
    rotator.reset_rotation()
    dialogues.universe_edge(comms_in, side)


func _blue_planet_event() -> void:
    await dialogues.blue_planet_intro(comms_in)


func _red_planet_event() -> void:
    pass


func _purple_planet_event() -> void:
    await dialogues.purple_planet_intro(comms_in)


func _orange_planet_event() -> void:
    await dialogues.orange_planet_intro(comms_in)
