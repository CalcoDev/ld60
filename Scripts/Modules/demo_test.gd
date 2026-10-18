extends Node

@onready var main_screen: MainScreenModule = %MainScreenLogic
@onready var thruster: ThrusterModule = %ThrusterLogic


func _ready() -> void:
    main_screen.get_output_port(&"power").connect_port(
        thruster.get_input_port(&"power")
    )
    thruster.get_output_port(&"data").connect_port(
        main_screen.get_input_port(&"data")
    )
