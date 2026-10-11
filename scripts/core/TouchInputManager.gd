class_name TouchInputManager
extends Node

## Mobile touch and raycasting controller for 3D creature and object interactions.
## Uses dedicated physics collision mask (Layer 2) to eliminate mobile raycast overhead.

const EventBusScript = preload("res://scripts/core/EventBus.gd")

@export var raycast_collision_mask: int = 2 # Layer 2: Clickable Entities
@export var ray_length: float = 100.0
@export var is_enabled: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled:
		return

	# Handle mobile touch
	if event is InputEventScreenTouch and event.pressed:
		_handle_screen_tap(event.position)
		return

	# Handle desktop / editor mouse click fallback
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_screen_tap(event.position)

func _handle_screen_tap(screen_position: Vector2) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * ray_length

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, raycast_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit_result: Dictionary = space_state.intersect_ray(query)

	var bus: Node = _get_event_bus()
	if bus == null:
		return

	if hit_result.is_empty():
		# Tapped empty ground or background
		_notify_deselection(bus)
		return

	var collider: Object = hit_result.get("collider")
	if collider == null:
		_notify_deselection(bus)
		return

	var monster_entity: MonsterEntity = _resolve_monster_entity(collider)
	if monster_entity != null and monster_entity.monster_data != null:
		_notify_monster_selected(bus, monster_entity.monster_data)
	else:
		_notify_deselection(bus)

func _resolve_monster_entity(collider: Object) -> MonsterEntity:
	if collider.has_meta("monster_entity"):
		var entity_candidate: Variant = collider.get_meta("monster_entity")
		if entity_candidate is MonsterEntity:
			return entity_candidate as MonsterEntity

	if collider is MonsterEntity:
		return collider as MonsterEntity

	if collider is Node:
		var parent: Node = (collider as Node).get_parent()
		if parent is MonsterEntity:
			return parent as MonsterEntity

	return null

func _notify_monster_selected(bus: Node, monster: MonsterInstance) -> void:
	if bus.has_signal("monster_selected"):
		bus.monster_selected.emit(monster)

func _notify_deselection(bus: Node) -> void:
	if bus.has_signal("monster_deselected"):
		bus.monster_deselected.emit()

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
