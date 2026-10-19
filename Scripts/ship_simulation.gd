class_name ShipSimulation
extends Node

const GRID_SIZE := Vector2i(8, 8)
const ROW_NAMES := "ABCDEFGH"

@export var tile_size := 128.0
@export var player_speed := 16.0
@export var starting_cell: StringName = &"D4"

var player_position := Vector2.ZERO
var player_angle := 0.0
var player_velocity := 0.0
var objects := {
    &"blue_planet": {"cell": &"B2"},
    &"red_planet": {"cell": &"F1"},
    &"purple_planet": {"cell": &"C7"},
    &"brown_planet": {"cell": &"G6"},
}

var _thrust_input := 0.0
var _rotation_input := 0.0


func _ready() -> void:
    Globals.ship_simulation = self
    player_position = cell_to_position(starting_cell)


func _exit_tree() -> void:
    if Globals.ship_simulation == self:
        Globals.ship_simulation = null


func _physics_process(delta: float) -> void:
    player_angle = wrapf(
        player_angle + _rotation_input * delta,
        0.0,
        TAU
    )
    player_velocity = _thrust_input * player_speed
    player_position += (
        Vector2.RIGHT.rotated(player_angle) * player_velocity * delta
    )
    player_position = player_position.clamp(
        Vector2.ZERO,
        get_map_size() - Vector2.ONE * 0.001
    )


func set_controls(data: Dictionary) -> void:
    if not data.get("power", false):
        clear_controls()
        return
    
    _thrust_input = float(data.get("thrust", 0.0))
    _rotation_input = float(data.get("rotation", 0.0))


func clear_controls() -> void:
    _thrust_input = 0.0
    _rotation_input = 0.0


func get_map_size() -> Vector2:
    return Vector2(GRID_SIZE) * tile_size


func get_player_cell() -> StringName:
    return position_to_cell(player_position)


func get_object_position(object_id: StringName) -> Vector2:
    var object_data: Dictionary = objects.get(object_id, {})
    return cell_to_position(object_data.get("cell", &"A0"))


func cell_to_position(cell_name: StringName) -> Vector2:
    var cell_text := String(cell_name).to_upper()
    if cell_text.length() < 2:
        return Vector2.ZERO
    
    var row := ROW_NAMES.find(cell_text.substr(0, 1))
    var column := int(cell_text.substr(1))
    row = clampi(row, 0, GRID_SIZE.y - 1)
    column = clampi(column, 0, GRID_SIZE.x - 1)
    var screen_row := GRID_SIZE.y - row - 1
    return (
        Vector2(column, screen_row) + Vector2.ONE * 0.5
    ) * tile_size


func position_to_cell(position: Vector2) -> StringName:
    var cell := Vector2i(floor(position / tile_size))
    cell.x = clampi(cell.x, 0, GRID_SIZE.x - 1)
    cell.y = clampi(cell.y, 0, GRID_SIZE.y - 1)
    var row := GRID_SIZE.y - cell.y - 1
    return StringName(
        "%s%d" % [ROW_NAMES.substr(row, 1), cell.x]
    )
