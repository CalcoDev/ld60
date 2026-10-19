class_name MainScreenMovementMenu
extends Control

@onready var velocity_label: Label = $ScreenMask/Velocity
@onready var angle_label: Label = $ScreenMask/Angle
@onready var cell_label: Label = $ScreenMask/Cell
@onready var grid: TextureRect = $ScreenMask/Grid
@onready var player_icon: TextureRect = $ScreenMask/PlayerIcon

@onready var object_visuals := {
    &"blue_planet": $ScreenMask/BluePlanet,
    &"red_planet": $ScreenMask/RedPlanet,
    &"purple_planet": $ScreenMask/PurplePlanet,
    &"brown_planet": $ScreenMask/BrownPlanet,
}


func _ready() -> void:
    player_icon.pivot_offset = player_icon.size * 0.5


func _process(_delta: float) -> void:
    var simulation := Globals.ship_simulation
    if simulation == null:
        return
    
    velocity_label.text = "VELO: %.1f" % simulation.player_velocity
    angle_label.text = "ANGL: %03.0f" % rad_to_deg(
        simulation.player_angle
    )
    cell_label.text = "CELL: %s" % simulation.get_player_cell()
    _place_visual(player_icon, simulation.player_position)
    player_icon.rotation = simulation.player_angle
    
    for object_id: StringName in object_visuals:
        _place_visual(
            object_visuals[object_id],
            simulation.get_object_position(object_id)
        )


func _place_visual(visual: Control, world_position: Vector2) -> void:
    var simulation := Globals.ship_simulation
    var normalized_position := world_position / simulation.get_map_size()
    visual.position = (
        grid.position
        + normalized_position * grid.size
        - visual.size * 0.5
    )
