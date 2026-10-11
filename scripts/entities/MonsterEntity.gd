class_name MonsterEntity
extends CharacterBody3D

## 3D Monster Controller executing physical movement, wandering FSM, and eating interactions.
## Decoupled from core logic by binding to MonsterInstance data resource and EventBus signals.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const TimeManagerScript = preload("res://scripts/core/TimeManager.gd")

enum State {
	IDLE,
	WANDER,
	EATING
}

@export_group("Monster Data & Husbandry")
@export var monster_data: MonsterInstance:
	set(value):
		monster_data = value
		if monster_data != null:
			_apply_monster_data()

@export_group("Locomotion")
@export var move_speed: float = 2.2
@export var rotation_speed: float = 7.0
@export var pen_reference: Pen3D = null

var model_container: Node3D:
	get:
		if _model_container == null:
			_model_container = get_node_or_null("ModelContainer")
		if _model_container == null:
			_ensure_components()
		return _model_container
var _model_container: Node3D = null

var collision_shape: CollisionShape3D:
	get:
		if _collision_shape == null:
			_collision_shape = get_node_or_null("CollisionShape3D")
		if _collision_shape == null:
			_ensure_components()
		return _collision_shape
var _collision_shape: CollisionShape3D = null

var tap_area: Area3D:
	get:
		if _tap_area == null:
			_tap_area = get_node_or_null("TapArea3D")
		if _tap_area == null:
			_ensure_components()
		return _tap_area
var _tap_area: Area3D = null

var current_state: State = State.IDLE
var state_timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var eating_duration: float = 2.0
var cached_anim_player: AnimationPlayer = null

# Procedural fallback tween for animations
var procedural_tween: Tween = null

func _enter_tree() -> void:
	_ensure_components()
	_connect_event_bus()

func _ready() -> void:
	_ensure_components()
	_connect_event_bus()
	if monster_data != null:
		_apply_monster_data()
	_enter_state(State.IDLE)

func _ensure_components() -> void:
	# Ensure ModelContainer
	if _model_container == null:
		_model_container = get_node_or_null("ModelContainer")
	if _model_container == null:
		_model_container = Node3D.new()
		_model_container.name = "ModelContainer"
		add_child(_model_container)

	# Ensure CollisionShape3D
	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape3D")
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 0.7
		_collision_shape.shape = cap
		_collision_shape.position.y = 0.35
		add_child(_collision_shape)

	# Ensure TapArea3D on Layer 2
	if _tap_area == null:
		_tap_area = get_node_or_null("TapArea3D")
	if _tap_area == null:
		_tap_area = Area3D.new()
		_tap_area.name = "TapArea3D"
		var col := CollisionShape3D.new()
		var tap_cap := CapsuleShape3D.new()
		tap_cap.radius = 0.55
		tap_cap.height = 1.1
		col.shape = tap_cap
		col.position.y = 0.45
		_tap_area.add_child(col)
		add_child(_tap_area)

	_tap_area.collision_layer = 2
	_tap_area.collision_mask = 0
	_tap_area.set_meta("monster_entity", self)

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return

	if bus.has_signal("beast_fed") and not bus.beast_fed.is_connected(_on_beast_fed_event):
		bus.beast_fed.connect(_on_beast_fed_event)

	if bus.has_signal("hour_ticked") and not bus.hour_ticked.is_connected(_on_hour_ticked):
		bus.hour_ticked.connect(_on_hour_ticked)

	if bus.has_signal("day_ticked") and not bus.day_ticked.is_connected(_on_day_ticked):
		bus.day_ticked.connect(_on_day_ticked)

func _apply_monster_data() -> void:
	if monster_data == null:
		return

	_ensure_components()

	# Load species 3D model if provided
	if monster_data.current_species != null and not monster_data.current_species.model_path.is_empty():
		_load_species_model(monster_data.current_species.model_path)

## Instances a species model into ModelContainer and discovers its AnimationPlayer.
func _load_species_model(path: String) -> void:
	if not ResourceLoader.exists(path):
		return

	var scene_res: PackedScene = load(path)
	if scene_res == null:
		return

	var container: Node3D = model_container
	# Clear previous model children
	for child in container.get_children():
		child.queue_free()

	var instance: Node = scene_res.instantiate()
	container.add_child(instance)
	cached_anim_player = _find_animation_player(instance)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.WANDER:
			_process_wander_state(delta)
		State.EATING:
			_process_eating_state(delta)

	# Physical clamp within pen boundaries
	if pen_reference != null and current_state != State.EATING:
		global_position = pen_reference.get_clamped_position(global_position)

func _process_idle_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
	if is_inside_tree():
		move_and_slide()

	state_timer -= delta
	if state_timer <= 0.0:
		_pick_wander_target()
		_enter_state(State.WANDER)

func _process_wander_state(delta: float) -> void:
	var cur_pos: Vector3 = global_position if is_inside_tree() else position
	var to_target: Vector3 = wander_target - cur_pos
	to_target.y = 0.0
	var dist: float = to_target.length()

	state_timer -= delta

	if dist < 0.3 or state_timer <= 0.0:
		_enter_state(State.IDLE)
		return

	var move_dir: Vector3 = to_target.normalized()

	# Smooth rotation toward destination
	if move_dir.length_squared() > 0.001:
		var target_angle: float = atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	if is_inside_tree():
		move_and_slide()

func _process_eating_state(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_inside_tree():
		move_and_slide()

	state_timer -= delta
	if state_timer <= 0.0:
		_enter_state(State.IDLE)

func _pick_wander_target() -> void:
	if pen_reference != null:
		wander_target = pen_reference.get_random_point_in_pen()
	else:
		# Fallback wander radius
		var rand_offset: Vector3 = Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
		var cur_pos: Vector3 = global_position if is_inside_tree() else position
		wander_target = cur_pos + rand_offset

func _enter_state(new_state: State) -> void:
	current_state = new_state

	match current_state:
		State.IDLE:
			state_timer = randf_range(2.0, 5.0)
			play_animation("idle")
		State.WANDER:
			state_timer = randf_range(3.0, 7.0)
			play_animation("walk")
		State.EATING:
			state_timer = eating_duration
			play_animation("eat")

## Executes the feeding sequence: stops movement, faces food/trough, and plays eating animation.
func trigger_eating(food_pos: Vector3 = Vector3.ZERO) -> void:
	if food_pos != Vector3.ZERO:
		var cur_pos: Vector3 = global_position if is_inside_tree() else position
		var dir_to_food: Vector3 = food_pos - cur_pos
		dir_to_food.y = 0.0
		if dir_to_food.length_squared() > 0.01:
			var target_rot: float = atan2(dir_to_food.x, dir_to_food.z)
			rotation.y = target_rot

	_enter_state(State.EATING)

## Feeds the monster with a CropData instance.
func feed(crop: CropData, food_pos: Vector3 = Vector3.ZERO) -> void:
	if crop == null:
		return

	if monster_data != null:
		monster_data.feed(crop)

	trigger_eating(food_pos)

func _on_beast_fed_event(p_beast_id: String, _crop_id: String) -> void:
	if monster_data != null and monster_data.beast_id == p_beast_id:
		var target_food_pos: Vector3 = pen_reference.get_trough_position() if pen_reference != null else Vector3.ZERO
		trigger_eating(target_food_pos)

func _on_hour_ticked(_hour: int) -> void:
	if monster_data != null:
		monster_data.satiety = clampi(monster_data.satiety - 1, 0, 100)

func _on_day_ticked(_day: int) -> void:
	if monster_data != null:
		monster_data.process_daily_tick()

## Safely plays an animation by name or falls back to procedural squash-and-stretch.
func play_animation(anim_name: String) -> void:
	var anim_player: AnimationPlayer = _get_or_find_anim_player()
	var played: bool = false

	if anim_player != null:
		var resolved: String = _resolve_animation_name(anim_player, anim_name)
		if not resolved.is_empty():
			anim_player.play(resolved)
			played = true

	if not played:
		_play_procedural_fallback(anim_name)

func _resolve_animation_name(player: AnimationPlayer, requested: String) -> String:
	var list: PackedStringArray = player.get_animation_list()
	if list.is_empty():
		return ""

	var lower_req: String = requested.to_lower()

	# Exact match
	for anim in list:
		if anim.to_lower() == lower_req:
			return anim

	# Substring match (e.g., "walk" matching "Burrow@Walk Forward In Place" or "Take 001")
	for anim in list:
		var lower_anim: String = anim.to_lower()
		if lower_req == "walk" and ("walk" in lower_anim or "run" in lower_anim):
			return anim
		elif lower_req == "idle" and ("idle" in lower_anim or "stand" in lower_anim):
			return anim
		elif lower_req == "eat" and ("eat" in lower_anim or "chew" in lower_anim or "attack" in lower_anim):
			return anim

	# Default fallback to first animation if idle or walk
	if lower_req in ["idle", "walk"]:
		return list[0]

	return ""

## Procedural secondary motion animation fallback if skeletal animation clip is unavailable.
func _play_procedural_fallback(anim_type: String) -> void:
	var container: Node3D = model_container
	if container == null or not is_inside_tree():
		return

	if procedural_tween != null and procedural_tween.is_valid():
		procedural_tween.kill()

	procedural_tween = create_tween()
	match anim_type.to_lower():
		"eat":
			procedural_tween.tween_property(container, "rotation:x", deg_to_rad(20.0), 0.2)
			procedural_tween.tween_property(container, "rotation:x", deg_to_rad(-10.0), 0.2)
			procedural_tween.tween_property(container, "rotation:x", 0.0, 0.2)
			procedural_tween.set_loops(3)
		"walk":
			procedural_tween.tween_property(container, "rotation:z", deg_to_rad(6.0), 0.2)
			procedural_tween.tween_property(container, "rotation:z", deg_to_rad(-6.0), 0.2)
			procedural_tween.tween_property(container, "rotation:z", 0.0, 0.1)
			procedural_tween.set_loops()
		"idle":
			procedural_tween.tween_property(container, "scale", Vector3(1.02, 0.97, 1.02), 1.2)
			procedural_tween.tween_property(container, "scale", Vector3(0.98, 1.03, 0.98), 1.2)
			procedural_tween.tween_property(container, "scale", Vector3.ONE, 0.6)
			procedural_tween.set_loops()

func _get_or_find_anim_player() -> AnimationPlayer:
	if is_instance_valid(cached_anim_player):
		return cached_anim_player
	cached_anim_player = _find_animation_player(self)
	return cached_anim_player

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
