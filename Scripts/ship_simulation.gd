class_name ShipSimulation
extends Node

signal object_reached(object_id: StringName)
signal object_left(object_id: StringName)
signal map_edge_reached(side: StringName)

const GRID_SIZE := Vector2i(8, 8)
const ROW_NAMES := "ABCDEFGH"
const EDGE_THRESHOLD := 1.0

@export var tile_size := 128.0
@export var player_speed := 16.0
@export var starting_cell: StringName = &"D4"

var player_position := Vector2.ZERO
var player_angle := 0.0
var player_velocity := 0.0
var objects := {
    &"blue_planet": {"cell": &"D0"},
    &"red_planet": {"cell": &"F1"},
    &"purple_planet": {"cell": &"C7"},
    &"orange_planet": {"cell": &"G6"},
}

var _thrust_input := 0.0
var _rotation_input := 0.0
var _reached_objects: Dictionary[StringName, bool] = {}
var _nearby_objects: Dictionary[StringName, bool] = {}
var _left_objects: Dictionary[StringName, bool] = {}
var _reached_edges: Dictionary[StringName, bool] = {}


func _ready() -> void:
    Globals.ship_simulation = self
    player_position = cell_to_position(starting_cell)


func _exit_tree() -> void:
    if Globals.ship_simulation == self:
        Globals.ship_simulation = null


func _process(_delta: float) -> void:
    for object_id: StringName in objects:
        var is_near := get_distance_to_object(object_id) <= tile_size
        var was_near: bool = _nearby_objects.get(object_id, false)
        if is_near:
            _nearby_objects[object_id] = true
            if not _reached_objects.has(object_id):
                _reached_objects[object_id] = true
                clear_controls()
                player_velocity = 0.0
                object_reached.emit(object_id)
        elif was_near:
            _nearby_objects.erase(object_id)
            if not _left_objects.has(object_id):
                _left_objects[object_id] = true
                object_left.emit(object_id)
    
    _check_map_edge()


func _check_map_edge() -> void:
    var map_size := get_map_size()
    var distances := {
        &"left": player_position.x,
        &"right": map_size.x - player_position.x,
        &"top": player_position.y,
        &"bottom": map_size.y - player_position.y,
    }
    var closest_side: StringName
    var closest_distance := INF
    for side: StringName in distances:
        var distance: float = distances[side]
        if distance < closest_distance:
            closest_distance = distance
            closest_side = side
    
    if (
        closest_distance <= EDGE_THRESHOLD
        and not _reached_edges.has(closest_side)
    ):
        _reached_edges[closest_side] = true
        clear_controls()
        player_velocity = 0.0
        map_edge_reached.emit(closest_side)


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


func get_distance_to_object(object_id: StringName) -> float:
    return player_position.distance_to(get_object_position(object_id))


func has_discovered_object(object_id: StringName) -> bool:
    return _reached_objects.has(object_id)


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
