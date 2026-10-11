class_name Pen3D
extends Node3D

## Spatial 3D Pen structure occupying discrete cells on GridManager.
## Manages pen capacity, assigned MonsterInstances, physical clamping bounds, and a feeding trough.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const GridManagerScript = preload("res://scripts/core/GridManager.gd")

@export_group("Grid Configuration")
@export var pen_id: String = "pen_alpha"
@export var grid_origin: Vector2i = Vector2i(0, 0)
@export var pen_size: Vector2i = Vector2i(3, 3)
@export var cell_size: float = 2.0

@export_group("Capacity & Monsters")
@export var max_capacity: int = 3
@export var assigned_monsters: Array[MonsterInstance] = []

@onready var trough_area: Area3D = get_node_or_null("TroughArea3D")
@onready var boundary_area: Area3D = get_node_or_null("BoundaryArea3D")

func _enter_tree() -> void:
	register_with_grid_manager()
	_update_transform_from_grid()

func _ready() -> void:
	register_with_grid_manager()
	_update_transform_from_grid()

## Registers all discrete grid cells covered by this pen with the GridManager.
func register_with_grid_manager() -> void:
	var grid: GridManager = _get_grid_manager()
	if grid == null:
		return

	for gx in range(pen_size.x):
		for gy in range(pen_size.y):
			var cell_pos: Vector2i = grid_origin + Vector2i(gx, gy)
			grid.occupy_cell(cell_pos, GridManager.CellType.PEN, pen_id)

## Aligns root Node3D position to match grid_origin world coordinates.
func _update_transform_from_grid() -> void:
	var grid: GridManager = _get_grid_manager()
	var effective_cell_size: float = grid.cell_size if grid != null else cell_size
	position = Vector3(float(grid_origin.x) * effective_cell_size, 0.0, float(grid_origin.y) * effective_cell_size)

## Returns the Axis-Aligned Bounding Box (AABB) of the pen in world space.
func get_pen_world_bounds() -> AABB:
	var grid: GridManager = _get_grid_manager()
	var effective_cell_size: float = grid.cell_size if grid != null else cell_size
	var origin_pos: Vector3 = global_position if is_inside_tree() else position
	var size_3d: Vector3 = Vector3(float(pen_size.x) * effective_cell_size, 3.0, float(pen_size.y) * effective_cell_size)
	return AABB(origin_pos, size_3d)

## Returns a random reachable 3D position inside the pen with padding from the fence edges.
func get_random_point_in_pen(padding: float = 0.6) -> Vector3:
	var bounds: AABB = get_pen_world_bounds()
	var min_x: float = bounds.position.x + padding
	var max_x: float = bounds.position.x + bounds.size.x - padding
	var min_z: float = bounds.position.z + padding
	var max_z: float = bounds.position.z + bounds.size.z - padding

	var rx: float = randf_range(min_x, max_x)
	var rz: float = randf_range(min_z, max_z)
	return Vector3(rx, 0.0, rz)

## Clamps any 3D coordinate to remain strictly inside the physical perimeter of the pen.
func get_clamped_position(target_pos: Vector3, padding: float = 0.5) -> Vector3:
	var bounds: AABB = get_pen_world_bounds()
	var clamped_x: float = clampf(target_pos.x, bounds.position.x + padding, bounds.position.x + bounds.size.x - padding)
	var clamped_z: float = clampf(target_pos.z, bounds.position.z + padding, bounds.position.z + bounds.size.z - padding)
	return Vector3(clamped_x, target_pos.y, clamped_z)

## Returns true if the given world position falls inside the pen.
func is_position_inside(pos: Vector3) -> bool:
	return get_pen_world_bounds().has_point(pos)

## Returns the 3D position of the feeding trough.
func get_trough_position() -> Vector3:
	if trough_area == null:
		trough_area = get_node_or_null("TroughArea3D")
	if trough_area != null:
		if trough_area.is_inside_tree():
			return trough_area.global_position
		var origin_pos: Vector3 = global_position if is_inside_tree() else position
		return origin_pos + trough_area.position

	var bounds: AABB = get_pen_world_bounds()
	return Vector3(bounds.position.x + (bounds.size.x * 0.5), bounds.position.y + 0.2, bounds.position.z + 0.6)

## Assigns a monster instance to this pen if capacity permits.
func assign_monster(monster: MonsterInstance) -> bool:
	if monster == null or assigned_monsters.size() >= max_capacity:
		return false
	if not assigned_monsters.has(monster):
		assigned_monsters.append(monster)
	return true

## Removes a monster from this pen.
func remove_monster(monster: MonsterInstance) -> bool:
	if assigned_monsters.has(monster):
		assigned_monsters.erase(monster)
		return true
	return false

## Deposits a crop into the pen's trough, distributing food or notifying monsters.
func deposit_food(crop: CropData) -> void:
	if crop == null:
		return

	# If there are monsters in the pen, feed the first hungry monster or currently selected
	if assigned_monsters.is_empty():
		return

	var target_monster: MonsterInstance = assigned_monsters[0]
	target_monster.feed(crop)

func _get_grid_manager() -> GridManager:
	if is_instance_valid(GridManager.instance):
		return GridManager.instance
	if is_instance_valid(GridManagerScript.instance):
		return GridManagerScript.instance
	if is_inside_tree() and has_node("/root/GridManager"):
		return get_node("/root/GridManager") as GridManager
	return null
