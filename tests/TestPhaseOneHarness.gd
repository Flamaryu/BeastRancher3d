class_name TestPhaseOneHarness
extends SceneTree

## Headless test harness verifying Phase 1 systems:
## - EventBus signals
## - TimeManager hour/day ticking
## - GridManager spatial coordinate math and cell occupancy
## - CropData nutritional effects and catalytic points
## - MonsterInstance husbandry, daily growth ticks, evolution triggers, and appraisal formula

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const TimeManagerScript = preload("res://scripts/core/TimeManager.gd")
const GridManagerScript = preload("res://scripts/core/GridManager.gd")
const CropDataScript = preload("res://scripts/resources/CropData.gd")
const SpeciesBlueprintScript = preload("res://scripts/resources/SpeciesBlueprint.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")

var event_bus: Node
var time_manager: Node
var grid_manager: GridManager

var fed_events: Array[Dictionary] = []
var evolved_events: Array[Dictionary] = []
var day_events: Array[int] = []
var hour_events: Array[int] = []

func _init() -> void:
	print("\n==================================================")
	print("  BEAST RANCHER 3D - PHASE 1 TEST HARNESS")
	print("==================================================\n")

	_setup_core_systems()
	_test_spatial_grid_math()
	_test_monster_raising_simulation()

	print("\n==================================================")
	print("  ALL PHASE 1 TESTS PASSED SUCCESSFULLY!")
	print("==================================================\n")
	quit(0)

func _setup_core_systems() -> void:
	print(">>> [1/3] Initializing Core Autoloads & Singletons...")

	# Ensure instances exist in headless SceneTree execution mode
	event_bus = EventBusScript.new()
	root.add_child(event_bus)

	time_manager = TimeManagerScript.new()
	root.add_child(time_manager)

	grid_manager = GridManagerScript.new()
	root.add_child(grid_manager)

	# Connect observers to EventBus
	event_bus.day_ticked.connect(func(day: int):
		day_events.append(day)
		print("  [SIGNAL] EventBus: day_ticked -> Day %d" % day)
	)

	event_bus.hour_ticked.connect(func(hour: int):
		hour_events.append(hour)
	)

	event_bus.beast_fed.connect(func(beast_id: String, crop_id: String):
		fed_events.append({"beast_id": beast_id, "crop_id": crop_id})
		print("  [SIGNAL] EventBus: beast_fed -> Beast '%s' fed with '%s'" % [beast_id, crop_id])
	)

	event_bus.beast_evolved.connect(func(beast_id: String, new_species_id: String):
		evolved_events.append({"beast_id": beast_id, "new_species_id": new_species_id})
		print("  [SIGNAL] EventBus: beast_evolved -> Beast '%s' evolved into '%s'!" % [beast_id, new_species_id])
	)

	print("  ✓ EventBus, TimeManager, and GridManager mounted & connected.\n")

func _test_spatial_grid_math() -> void:
	print(">>> [2/3] Verifying Spatial Grid & Coordinate Math...")
	grid_manager.cell_size = 2.0
	grid_manager.grid_size = Vector2i(10, 10)

	# 1. Coordinate Math: discrete Vector2i to 3D world space Vector3(x * cell_size, 0, y * cell_size)
	var test_grid_pos: Vector2i = Vector2i(3, 7)
	var expected_origin: Vector3 = Vector3(6.0, 0.0, 14.0)
	var actual_origin: Vector3 = grid_manager.grid_to_world(test_grid_pos, false)
	assert(actual_origin == expected_origin, "Grid to world origin conversion failed!")

	var expected_center: Vector3 = Vector3(7.0, 0.0, 15.0)
	var actual_center: Vector3 = grid_manager.grid_to_world(test_grid_pos, true)
	assert(actual_center == expected_center, "Grid to world center conversion failed!")

	var converted_back: Vector2i = grid_manager.world_to_grid(actual_center)
	assert(converted_back == test_grid_pos, "World to grid round-trip failed!")
	print("  ✓ Grid coordinates round-trip: %s -> %s -> %s" % [test_grid_pos, actual_origin, converted_back])

	# 2. Boundary and Cell State Checks
	assert(grid_manager.is_within_bounds(Vector2i(0, 0)), "Boundary check failed for origin")
	assert(grid_manager.is_within_bounds(Vector2i(9, 9)), "Boundary check failed for max corner")
	assert(not grid_manager.is_within_bounds(Vector2i(10, 10)), "Boundary check failed for out-of-bounds")

	assert(grid_manager.is_cell_empty(test_grid_pos), "Fresh cell should be empty")

	# Occupy as Pen
	grid_manager.occupy_cell(test_grid_pos, GridManager.CellType.PEN, "pen_alpha")
	assert(grid_manager.get_cell_type(test_grid_pos) == GridManager.CellType.PEN, "Cell type mismatch for PEN")
	assert(grid_manager.get_cell_occupant_id(test_grid_pos) == "pen_alpha", "Occupant ID mismatch")
	assert(not grid_manager.is_cell_empty(test_grid_pos), "Occupied cell should not be empty")

	# Occupy another cell as Crop Plot
	var crop_cell: Vector2i = Vector2i(4, 7)
	grid_manager.occupy_cell(crop_cell, GridManager.CellType.CROP_PLOT, "plot_beta")
	assert(grid_manager.get_cell_type(crop_cell) == GridManager.CellType.CROP_PLOT, "Cell type mismatch for CROP_PLOT")

	# Vacate
	grid_manager.vacate_cell(test_grid_pos)
	assert(grid_manager.is_cell_empty(test_grid_pos), "Vacated cell should be empty")

	print("  ✓ Grid occupancy and state transitions verified.\n")

func _test_monster_raising_simulation() -> void:
	print(">>> [3/3] Simulating 5-Day Monster Husbandry & Evolution Loop...")

	# 1. Define Species Blueprints
	var juvenile_species: SpeciesBlueprint = SpeciesBlueprintScript.new()
	juvenile_species.species_id = "pyro_pup"
	juvenile_species.species_name = "Pyro Pup"
	juvenile_species.tier = 1
	juvenile_species.element_type = "Fire"
	juvenile_species.base_atk = 12
	juvenile_species.base_def = 8
	juvenile_species.base_speed = 15
	juvenile_species.base_max_hp = 90
	juvenile_species.base_valuation = 300
	juvenile_species.min_evolution_days = 3
	juvenile_species.min_atk = 18
	juvenile_species.min_temperament = 60
	juvenile_species.min_satiety = 60
	juvenile_species.required_catalytic_points = {"fire": 15}

	var adult_species: SpeciesBlueprint = SpeciesBlueprintScript.new()
	adult_species.species_id = "inferno_hound"
	adult_species.species_name = "Inferno Hound"
	adult_species.tier = 2
	adult_species.element_type = "Fire"
	adult_species.base_atk = 30
	adult_species.base_def = 22
	adult_species.base_speed = 28
	adult_species.base_max_hp = 180
	adult_species.base_valuation = 1100

	# Link evolution target
	juvenile_species.evolves_to_species = adult_species
	juvenile_species.evolves_to_species_id = adult_species.species_id

	# 2. Define Custom Crop Resources
	var flame_melon: CropData = CropDataScript.new()
	flame_melon.crop_id = "flame_melon"
	flame_melon.display_name = "Flame Melon"
	flame_melon.growth_duration_days = 1
	flame_melon.atk_modifier = 3
	flame_melon.def_modifier = 0
	flame_melon.speed_modifier = 1
	flame_melon.satiety_restoration = 30
	flame_melon.temperament_modifier = 8
	flame_melon.evolution_catalytic_points = {"fire": 5}
	flame_melon.base_sell_price = 45

	var iron_root: CropData = CropDataScript.new()
	iron_root.crop_id = "iron_root"
	iron_root.display_name = "Iron Root"
	iron_root.growth_duration_days = 2
	iron_root.atk_modifier = 0
	iron_root.def_modifier = 4
	iron_root.speed_modifier = 0
	iron_root.satiety_restoration = 25
	iron_root.temperament_modifier = 4
	iron_root.evolution_catalytic_points = {"earth": 5}
	iron_root.base_sell_price = 35

	# 3. Create Monster Instance
	var monster: MonsterInstance = MonsterInstanceScript.new()
	monster.initialize(juvenile_species, "beast_007", "Blaze")
	monster.pedigree_rank = "A"
	monster.bloodline_purity = 0.95
	monster.gene_slots = ["Gene_HeatResist", "Gene_FastMetabolism"]
	monster.certification_grade = "Standard"

	var initial_value: int = monster.calculate_appraisal_value()
	print("--- Baseline Monster State (Day 0) ---")
	_print_monster_summary(monster, initial_value)

	# 4. 5-Day Simulation Loop
	# Feeding schedule:
	# Day 1: Flame Melon (+3 ATK, +5 Fire Catalytic)
	# Day 2: Iron Root (+4 DEF, +5 Earth Catalytic)
	# Day 3: Flame Melon (+3 ATK, +5 Fire Catalytic) -> Catalytic now 10/15
	# Day 4: Flame Melon (+3 ATK, +5 Fire Catalytic) -> Catalytic reaches 15/15! Evolution triggers!
	# Day 5: Maintenance & Final Appraisal

	var daily_crops: Array[CropData] = [flame_melon, iron_root, flame_melon, flame_melon, null]

	for day_idx in range(5):
		var sim_day: int = day_idx + 1
		print("\n--------------------------------------------------")
		print("  SIMULATION DAY %d" % sim_day)
		print("--------------------------------------------------")

		# Feeding phase
		var crop: CropData = daily_crops[day_idx]
		if crop != null:
			print("  [Action] Feeding '%s' to '%s'..." % [crop.display_name, monster.nickname])
			monster.feed(crop)
			print("    -> Nutritional effects applied: ATK=%d, DEF=%d, Satiety=%d, Catalytic=%s" % [
				monster.current_atk, monster.current_def, monster.satiety, str(monster.catalytic_points)
			])
		else:
			print("  [Action] Fasting / Rest Day (No crop fed).")

		# Time advancement: Advance clock 24 hours
		time_manager.advance_day()

		# Daily metabolic tick
		monster.process_daily_tick()

		# Valuation
		var current_val: int = monster.calculate_appraisal_value()
		print("  [Status Check] Day %d End:" % sim_day)
		_print_monster_summary(monster, current_val)

	# 5. Assertions to confirm system integrity
	assert(monster.stage == "adult", "Monster should have evolved to adult stage!")
	assert(monster.current_species.species_id == "inferno_hound", "Species ID should be inferno_hound!")
	assert(evolved_events.size() == 1, "Expected exactly 1 evolution event to be emitted!")
	assert(fed_events.size() == 4, "Expected 4 feeding events to be recorded!")
	assert(monster.calculate_appraisal_value() > initial_value, "Adult evolved beast must have higher appraisal value than juvenile baseline!")
	print("\n  ✓ 5-Day simulation assertions confirmed!")

func _print_monster_summary(monster: MonsterInstance, appraisal: int) -> void:
	print("    • Beast: '%s' [%s] | Species: %s (%s, Tier %d)" % [
		monster.nickname, monster.beast_id, monster.current_species.species_name, monster.stage.to_upper(), monster.current_species.tier
	])
	print("    • Stats: ATK %d | DEF %d | SPD %d | HP %d" % [
		monster.current_atk, monster.current_def, monster.current_speed, monster.current_max_hp
	])
	print("    • Husbandry: Satiety %d/100 | Hygiene %d/100 | Temperament %d/100" % [
		monster.satiety, monster.hygiene, monster.temperament
	])
	print("    • Genetics: Pedigree %s | Purity %.0f%% | Gene Slots: %s" % [
		monster.pedigree_rank, monster.bloodline_purity * 100.0, str(monster.gene_slots)
	])
	print("    • Catalytic Points: %s | Diet History: %s" % [
		str(monster.catalytic_points), str(monster.diet_history)
	])
	print("    • Calculated Appraisal Value: %d Gold" % appraisal)
