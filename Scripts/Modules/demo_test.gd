extends Node

@onready var simulation: ShipSimulation = $"../ShipSimulation"
@onready var thruster: ThrusterModule = (
    $"../CanvasLayer/Boxes/Thruster/ThrusterLogic"
)
@onready var rotator: RotatorModule = (
    $"../CanvasLayer/Boxes/Rotator/RotatorLogic"
)
@onready var comms_in: CommsInModule = (
    $"../CanvasLayer/Boxes/CommsIn/CommsInLogic"
)

var dialogues := GameDialogues.new()


func _ready() -> void:
    add_child(dialogues)
    simulation.object_reached.connect(_on_object_reached)


func _on_object_reached(object_id: StringName) -> void:
    if object_id != &"blue_planet":
        return
    
    thruster.reset_thrust()
    rotator.reset_rotation()
    dialogues.demo_gleep_call(comms_in)
