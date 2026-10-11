class_name GridManager
extends Node

## Spatial Grid Manager for discrete 2D grid coordinates and 3D world space conversions.
## Optimized for mobile performance: zero heavy physics lookups, fast hash-based cell occupancy queries.

const EventBusScript = preload("res://scripts/core/EventBus.gd")

enum CellType {
	EMPTY = 0,
	PEN = 1,
	CROP_PLOT = 2,
	OBSTACLE = 3,
}

@export var grid_size: Vector2i = Vector2i(20, 20)
@export var cell_size: float = 2.0

## Internal storage mapping Vector2i grid positions to occupancy data.
## Structure: { "type": CellType, "occupant_id": String, "metadata": Dictionary }
var _grid_cells: Dictionary = {}

static var instance: GridManager = null

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

## Converts discrete 2D grid coordinate (Vector2i) to 3D world space coordinate.
## Implements the project constraint: Vector3(x * cell_size, 0, y * cell_size).
## When centered is true, returns the center point of the cell.
func grid_to_world(grid_pos: Vector2i, centered: bool = false) -> Vector3:
	var offset: Vector3 = Vector3(cell_size * 0.5, 0.0, cell_size * 0.5) if centered else Vector3.ZERO
	return Vector3(float(grid_pos.x) * cell_size, 0.0, float(grid_pos.y) * cell_size) + offset

## Maps a continuous 3D world space point back to the discrete 2D grid coordinate.
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var gx: int = int(floor(world_pos.x / cell_size))
	var gy: int = int(floor(world_pos.z / cell_size))
	return Vector2i(gx, gy)

## Checks if grid position is within current bounds [0, grid_size - 1].
func is_within_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y

## Sets cell type directly if position is within bounds.
func set_cell_type(grid_pos: Vector2i, cell_type: CellType) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	if cell_type == CellType.EMPTY:
		return vacate_cell(grid_pos)

	return occupy_cell(grid_pos, cell_type)

## Returns current cell type. Defaults to CellType.EMPTY if untracked.
func get_cell_type(grid_pos: Vector2i) -> CellType:
	if not is_within_bounds(grid_pos):
		return CellType.OBSTACLE
	if _grid_cells.has(grid_pos):
		return _grid_cells[grid_pos].get("type", CellType.EMPTY) as CellType
	return CellType.EMPTY

## Checks whether a cell is valid and empty.
func is_cell_empty(grid_pos: Vector2i) -> bool:
	if not is_within_bounds(grid_pos):
		return false
	return get_cell_type(grid_pos) == CellType.EMPTY

## Marks a cell as occupied by a pen, crop plot, or obstacle with optional occupant ID.
func occupy_cell(grid_pos: Vector2i, cell_type: CellType, occupant_id: String = "", metadata: Dictionary = {}) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	_grid_cells[grid_pos] = {
		"type": cell_type,
		"occupant_id": occupant_id,
		"metadata": metadata
	}

	_notify_cell_changed(grid_pos, cell_type, occupant_id)
	return true

## Vacates a cell back to EMPTY.
func vacate_cell(grid_pos: Vector2i) -> bool:
	if not is_within_bounds(grid_pos):
		return false

	var was_present: bool = _grid_cells.erase(grid_pos)
	if was_present:
		_notify_cell_changed(grid_pos, CellType.EMPTY, "")
	return true

## Gets the unique occupant ID assigned to a cell (e.g. monster_id or plot_id).
func get_cell_occupant_id(grid_pos: Vector2i) -> String:
	if _grid_cells.has(grid_pos):
		return _grid_cells[grid_pos].get("occupant_id", "")
	return ""

## Returns all occupied cells matching a specific CellType.
func get_cells_by_type(cell_type: CellType) -> Array[Vector2i]:
	var matching: Array[Vector2i] = []
	for pos in _grid_cells.keys():
		if _grid_cells[pos].get("type", CellType.EMPTY) == cell_type:
			matching.append(pos)
	return matching

## Resets all cell occupancy data.
func clear_grid() -> void:
	_grid_cells.clear()

func _notify_cell_changed(pos: Vector2i, cell_type: CellType, occupant_id: String) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("cell_state_changed"):
		bus.cell_state_changed.emit(pos, int(cell_type), occupant_id)

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
