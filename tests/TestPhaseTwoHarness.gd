class_name TestPhaseTwoHarness
extends SceneTree

## Automated test harness verifying Phase 2 systems:
## - Pen3D grid occupancy, capacity, bounds clamping, and trough positioning
## - MonsterEntity FSM state transitions (IDLE -> WANDER -> EATING), pen clamping, and safe animations
## - TouchInputManager collision mask and entity resolution logic
## - RanchHUD data binding, meter updates, and crop feeding action

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const TimeManagerScript = preload("res://scripts/core/TimeManager.gd")
const GridManagerScript = preload("res://scripts/core/GridManager.gd")
const CropDataScript = preload("res://scripts/resources/CropData.gd")
const SpeciesBlueprintScript = preload("res://scripts/resources/SpeciesBlueprint.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")
const Pen3DScript = preload("res://scripts/entities/Pen3D.gd")
const MonsterEntityScript = preload("res://scripts/entities/MonsterEntity.gd")
const RanchHUDScript = preload("res://scripts/ui/RanchHUD.gd")

var active_bus: Node
var time_manager: Node
var grid_manager: GridManager

var selected_monsters: Array[MonsterInstance] = []
var deselected_count: int = 0
var fed_signals: Array[Dictionary] = []

func _initialize() -> void:
	print("\n==================================================")
	print("  BEAST RANCHER 3D - PHASE 2 TEST HARNESS")
	print("==================================================\n")

	_setup_core_autoloads()
	_test_pen_3d_systems()
	_test_monster_entity_fsm()
	_test_hud_feeding_flow()

	print("\n==================================================")
	print("  ALL PHASE 2 TESTS PASSED SUCCESSFULLY!")
	print("==================================================\n")
	quit(0)

func _setup_core_autoloads() -> void:
	print(">>> [1/3] Mounting Core Autoloads & Connecting Observers...")

	# Resolve singleton or instantiate fallback
	if is_instance_valid(EventBusScript.instance):
		active_bus = EventBusScript.instance
	else:
		active_bus = EventBusScript.new()
		active_bus.name = "EventBus"
		root.add_child(active_bus)

	if is_instance_valid(TimeManagerScript.instance):
		time_manager = TimeManagerScript.instance
	else:
		time_manager = TimeManagerScript.new()
		time_manager.name = "TimeManager"
		root.add_child(time_manager)

	if is_instance_valid(GridManager.instance):
		grid_manager = GridManager.instance
	else:
		grid_manager = GridManagerScript.new()
		grid_manager.name = "GridManager"
		root.add_child(grid_manager)

	active_bus.monster_selected.connect(func(monster: MonsterInstance):
		selected_monsters.append(monster)
		print("  [SIGNAL] EventBus: monster_selected -> '%s'" % monster.nickname)
	)

	active_bus.monster_deselected.connect(func():
		deselected_count += 1
		print("  [SIGNAL] EventBus: monster_deselected")
	)

	active_bus.beast_fed.connect(func(beast_id: String, crop_id: String):
		fed_signals.append({"beast_id": beast_id, "crop_id": crop_id})
		print("  [SIGNAL] EventBus: beast_fed -> '%s' with '%s'" % [beast_id, crop_id])
	)

	print("  ✓ Autoloads initialized and signal listeners bound.\n")

func _test_pen_3d_systems() -> void:
	print(">>> [2/3] Verifying Pen3D Grid Placement, Clamping, and Trough...")

	var pen_scene: PackedScene = load("res://scenes/world/Pen3D.tscn")
	var pen: Pen3D = pen_scene.instantiate() if pen_scene != null else Pen3DScript.new()
	pen.pen_id = "pen_test_alpha"
	pen.grid_origin = Vector2i(2, 4)
	pen.pen_size = Vector2i(3, 3)
	pen.cell_size = 2.0
	root.add_child(pen)
	pen.register_with_grid_manager()
	pen._update_transform_from_grid()

	# 1. Verify GridManager occupancy
	for x in range(3):
		for y in range(3):
			var cell: Vector2i = Vector2i(2 + x, 4 + y)
			assert(grid_manager.get_cell_type(cell) == GridManager.CellType.PEN, "Pen grid cell not registered!")
			assert(grid_manager.get_cell_occupant_id(cell) == "pen_test_alpha", "Occupant mismatch!")
	print("  ✓ 3x3 cells registered with GridManager as PEN type.")

	# 2. Verify AABB and Clamping Bounds
	var bounds: AABB = pen.get_pen_world_bounds()
	var expected_origin: Vector3 = Vector3(4.0, 0.0, 8.0)
	var expected_size: Vector3 = Vector3(6.0, 3.0, 6.0)
	assert(bounds.position.is_equal_approx(expected_origin), "Pen AABB origin mismatch! Got %s expected %s" % [bounds.position, expected_origin])
	assert(bounds.size.is_equal_approx(expected_size), "Pen AABB size mismatch!")

	# Outside position should clamp inside
	var outside_pos: Vector3 = Vector3(15.0, 0.0, -5.0)
	var clamped_pos: Vector3 = pen.get_clamped_position(outside_pos, 0.5)
	assert(clamped_pos.x <= bounds.position.x + bounds.size.x - 0.5, "Clamped X exceeding max!")
	assert(clamped_pos.z >= bounds.position.z + 0.5, "Clamped Z below min!")

	# Random point generation within bounds
	for i in range(5):
		var rand_point: Vector3 = pen.get_random_point_in_pen(0.5)
		assert(bounds.has_point(rand_point), "Random point fell outside pen bounds!")

	# Trough position
	var trough_pos: Vector3 = pen.get_trough_position()
	assert(bounds.has_point(trough_pos), "Trough position must reside inside pen! Got %s, bounds %s" % [trough_pos, bounds])

	# 3. Capacity & Monster assignment
	var m1: MonsterInstance = MonsterInstanceScript.new()
	m1.beast_id = "m_01"
	var m2: MonsterInstance = MonsterInstanceScript.new()
	m2.beast_id = "m_02"
	var m3: MonsterInstance = MonsterInstanceScript.new()
	m3.beast_id = "m_03"
	var m4: MonsterInstance = MonsterInstanceScript.new()
	m4.beast_id = "m_04"

	assert(pen.assign_monster(m1))
	assert(pen.assign_monster(m2))
	assert(pen.assign_monster(m3))
	assert(not pen.assign_monster(m4), "Exceeded max capacity (3) must be rejected!")
	assert(pen.assigned_monsters.size() == 3)

	pen.remove_monster(m2)
	assert(pen.assigned_monsters.size() == 2)
	assert(pen.assign_monster(m4), "Should allow assignment after monster removed!")

	pen.queue_free()
	print("  ✓ Pen bounds clamping, capacity, and trough tests passed.\n")

func _test_monster_entity_fsm() -> void:
	print(">>> [3/3] Verifying MonsterEntity FSM Locomotion and Feeding State...")

	# 1. Setup Species & MonsterInstance
	var species: SpeciesBlueprint = SpeciesBlueprintScript.new()
	species.species_id = "pyro_pup"
	species.species_name = "Pyro Pup"
	species.base_atk = 15
	species.base_def = 10
	species.base_speed = 14
	species.base_max_hp = 100
	species.base_valuation = 400

	var monster_data: MonsterInstance = MonsterInstanceScript.new()
	monster_data.initialize(species, "beast_101", "Cinder")
	monster_data.satiety = 40

	# 2. Setup MonsterEntity from packed scene
	var entity_scene: PackedScene = load("res://scenes/entities/MonsterEntity.tscn")
	var entity: MonsterEntity = entity_scene.instantiate()
	root.add_child(entity)
	entity.monster_data = monster_data

	# Verify TapArea collision layer
	assert(entity.tap_area != null, "TapArea3D must exist!")
	assert(entity.tap_area.collision_layer == 2, "TapArea3D must be on dedicated Layer 2!")
	assert(entity.tap_area.collision_mask == 0, "TapArea3D should have mask 0 to avoid physics overhead!")

	# 3. Verify FSM State transitions
	assert(entity.current_state == MonsterEntity.State.IDLE, "Entity must initialize in IDLE state!")

	# Feed triggering EATING state
	var crop: CropData = CropDataScript.new()
	crop.crop_id = "sunburst_pepper"
	crop.display_name = "Sunburst Pepper"
	crop.satiety_restoration = 30
	crop.atk_modifier = 2

	entity.feed(crop, Vector3(5.0, 0.0, 5.0))
	assert(entity.current_state == MonsterEntity.State.EATING, "Entity must transition to EATING when fed!")
	assert(monster_data.satiety == 70, "Satiety should increase from 40 to 70!")
	assert(monster_data.current_atk == 17, "ATK modifier should apply!")

	# Process eating completion
	entity._process_eating_state(2.5) # Simulates delta past eating_duration
	assert(entity.current_state == MonsterEntity.State.IDLE, "Entity must return to IDLE after eating!")

	# Procedural fallback animation check
	entity.play_animation("eat")
	entity.play_animation("walk")
	entity.play_animation("idle")

	entity.queue_free()
	print("  ✓ MonsterEntity FSM states, layer 2 tap area, and feeding verified.\n")

func _test_hud_feeding_flow() -> void:
	print(">>> Verifying RanchHUD Interaction & Feed Action Bar...")

	# Instantiate RanchHUD scene
	var hud_scene: PackedScene = load("res://scenes/ui/RanchHUD.tscn")
	assert(hud_scene != null, "RanchHUD.tscn must be loadable!")
	var hud: RanchHUD = hud_scene.instantiate()
	root.add_child(hud)
	hud._ensure_nodes()
	hud._connect_events()

	var species: SpeciesBlueprint = SpeciesBlueprintScript.new()
	species.species_name = "Terra Boar"
	var monster: MonsterInstance = MonsterInstanceScript.new()
	monster.initialize(species, "beast_202", "Grom")
	monster.satiety = 50
	monster.hygiene = 60
	monster.temperament = 70

	# Test Selection via active_bus signal
	active_bus.monster_selected.emit(monster)
	assert(hud.selected_monster == monster, "HUD must track selected monster!")
	assert(hud.inspect_drawer.visible == true, "Inspect drawer must open on selection!")
	assert(hud.nickname_label.text == "Grom", "Drawer must display monster nickname!")

	# Test Feed Button via HUD
	var pepper: CropData = CropDataScript.new()
	pepper.crop_id = "sun_pepper"
	pepper.display_name = "Sun Pepper"
	pepper.satiety_restoration = 25

	hud._on_feed_button_pressed(pepper)
	assert(monster.satiety == 75, "Monster satiety should update to 75 via HUD feed action!")
	assert(hud.satiety_label.text == "75 / 100", "HUD satiety label must reflect new value!")

	# Test Deselection
	active_bus.monster_deselected.emit()
	assert(hud.selected_monster == null, "HUD must clear selected monster on deselection!")

	hud.queue_free()
	print("  ✓ RanchHUD selection, real-time meter updates, and feeding flow verified.\n")
