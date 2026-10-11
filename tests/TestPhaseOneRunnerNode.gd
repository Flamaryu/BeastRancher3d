class_name TestPhaseOneRunnerNode
extends Node

## Scene runner for TestPhaseOne.
## Allows running Phase 1 verification tests from within the Godot Editor (F6) or via `godot tests/test_phase_one.tscn`.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const TimeManagerScript = preload("res://scripts/core/TimeManager.gd")
const GridManagerScript = preload("res://scripts/core/GridManager.gd")
const CropDataScript = preload("res://scripts/resources/CropData.gd")
const SpeciesBlueprintScript = preload("res://scripts/resources/SpeciesBlueprint.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")

func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING PHASE 1 TEST SCENE (EDITOR / RUNNER)")
	print("==================================================\n")

	_run_all_tests()

	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)

func _run_all_tests() -> void:
	_test_spatial_grid()
	_test_simulation_loop()

func _test_spatial_grid() -> void:
	print(">>> Verifying Spatial Grid...")
	var grid: GridManager = GridManagerScript.new()
	add_child(grid)
	grid.cell_size = 2.0
	grid.grid_size = Vector2i(10, 10)

	var pos: Vector2i = Vector2i(3, 7)
	var world_origin: Vector3 = grid.grid_to_world(pos, false)
	assert(world_origin == Vector3(6.0, 0.0, 14.0))

	var converted_back: Vector2i = grid.world_to_grid(world_origin)
	assert(converted_back == pos)

	grid.occupy_cell(pos, GridManager.CellType.PEN, "pen_1")
	assert(grid.get_cell_type(pos) == GridManager.CellType.PEN)
	assert(not grid.is_cell_empty(pos))

	grid.vacate_cell(pos)
	assert(grid.is_cell_empty(pos))
	print("  ✓ Spatial Grid Verified.\n")

func _test_simulation_loop() -> void:
	print(">>> Verifying Monster Husbandry Simulation...")

	# Species
	var pup: SpeciesBlueprint = SpeciesBlueprintScript.new()
	pup.species_id = "pyro_pup"
	pup.species_name = "Pyro Pup"
	pup.tier = 1
	pup.base_atk = 12
	pup.base_def = 8
	pup.base_speed = 15
	pup.base_max_hp = 90
	pup.base_valuation = 300
	pup.min_evolution_days = 3
	pup.min_atk = 18
	pup.min_temperament = 60
	pup.min_satiety = 60
	pup.required_catalytic_points = {"fire": 15}

	var hound: SpeciesBlueprint = SpeciesBlueprintScript.new()
	hound.species_id = "inferno_hound"
	hound.species_name = "Inferno Hound"
	hound.tier = 2
	hound.base_atk = 30
	hound.base_def = 22
	hound.base_speed = 28
	hound.base_max_hp = 180
	hound.base_valuation = 1100

	pup.evolves_to_species = hound
	pup.evolves_to_species_id = hound.species_id

	# Crop
	var flame_melon: CropData = CropDataScript.new()
	flame_melon.crop_id = "flame_melon"
	flame_melon.display_name = "Flame Melon"
	flame_melon.atk_modifier = 3
	flame_melon.satiety_restoration = 30
	flame_melon.evolution_catalytic_points = {"fire": 5}

	var monster: MonsterInstance = MonsterInstanceScript.new()
	monster.initialize(pup, "beast_007", "Blaze")
	monster.pedigree_rank = "A"
	monster.bloodline_purity = 0.95
	monster.gene_slots = ["Gene_HeatResist"]

	var init_val: int = monster.calculate_appraisal_value()
	print("  Initial Appraisal Value: %d Gold" % init_val)

	# Feed 3 times to accumulate catalytic points and stats
	monster.feed(flame_melon)
	monster.process_daily_tick()
	monster.feed(flame_melon)
	monster.process_daily_tick()
	monster.feed(flame_melon)
	monster.process_daily_tick()

	# Evolution check
	assert(monster.stage == "adult")
	assert(monster.current_species.species_id == "inferno_hound")
	var final_val: int = monster.calculate_appraisal_value()
	print("  Final Evolved Appraisal Value: %d Gold" % final_val)
	assert(final_val > init_val)
	print("  ✓ Husbandry Simulation Verified.\n")
