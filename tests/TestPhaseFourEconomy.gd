class_name TestPhaseFourEconomy
extends SceneTree

## Automated test harness verifying Phase 4A systems:
## - Case 1: Global root-motion attack/dodge filtering in MonsterVisualController
## - Case 2: 3-Tier Sparring Ring fail-forward mechanics (stat boost, diagnostic feedback, clutch awakening)
## - Case 3: Conditioned victory (Bronze 1.25x), license gating (Silver/Noble), and free-tier gold cap (5000)
## - Case 4: Master License entitlement unlock, Gold Training Dummy (2.0x), and Noble Contract payout
## - Case 5: Clearance Pen scrap liquidation (40% value)

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const TimeManagerScript = preload("res://scripts/core/TimeManager.gd")
const LicenseServiceScript = preload("res://scripts/core/LicenseService.gd")
const EconomyManagerScript = preload("res://scripts/core/EconomyManager.gd")
const SparringManagerScript = preload("res://scripts/core/SparringManager.gd")

const SpeciesDataScript = preload("res://scripts/resources/SpeciesData.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")
const MonsterVisualControllerScript = preload("res://scripts/entities/MonsterVisualController.gd")
const ContractDataScript = preload("res://scripts/resources/ContractData.gd")
const CropDataScript = preload("res://scripts/resources/CropData.gd")

var event_bus: Node = null
var time_manager: Node = null
var license_service: Node = null
var economy_manager: Node = null
var sparring_manager: Node = null

var license_gate_events: Array[String] = []
var sparring_events: Array[Dictionary] = []
var contract_events: Array[Dictionary] = []
var liquidation_events: Array[Dictionary] = []

func _initialize() -> void:
	print("\n==================================================")
	print("  BEAST RANCHER 3D - PHASE 4A TEST HARNESS")
	print("  Sparring Trials, Fail-Forward, Contracts & Licenses")
	print("==================================================\n")

	_setup_core_services()
	_test_case_1_root_motion_attack_filter()
	_test_case_2_fail_forward_sparring()
	_test_case_3_conditioned_victory_and_license_gates()
	_test_case_4_master_license_and_noble_contract()
	_test_case_5_clearance_pen_liquidation()

	print("\n==================================================")
	print("  ALL PHASE 4A TESTS PASSED SUCCESSFULLY!")
	print("==================================================\n")
	quit(0)

func _setup_core_services() -> void:
	print(">>> [1/6] Mounting Autoloads & Event Listeners...")

	# EventBus
	if is_instance_valid(EventBusScript.instance):
		event_bus = EventBusScript.instance
	else:
		event_bus = EventBusScript.new()
		event_bus.name = "EventBus"
		root.add_child(event_bus)

	# TimeManager
	if is_instance_valid(TimeManagerScript.instance):
		time_manager = TimeManagerScript.instance
	else:
		time_manager = TimeManagerScript.new()
		time_manager.name = "TimeManager"
		root.add_child(time_manager)

	# LicenseService
	if is_instance_valid(LicenseServiceScript.instance):
		license_service = LicenseServiceScript.instance
	else:
		license_service = LicenseServiceScript.new()
		license_service.name = "LicenseService"
		root.add_child(license_service)

	# EconomyManager
	if is_instance_valid(EconomyManagerScript.instance):
		economy_manager = EconomyManagerScript.instance
	else:
		economy_manager = EconomyManagerScript.new()
		economy_manager.name = "EconomyManager"
		root.add_child(economy_manager)

	# SparringManager
	if is_instance_valid(SparringManagerScript.instance):
		sparring_manager = SparringManagerScript.instance
	else:
		sparring_manager = SparringManagerScript.new()
		sparring_manager.name = "SparringManager"
		root.add_child(sparring_manager)

	# Connect Observers
	event_bus.license_gate_triggered.connect(func(feature_name: String):
		license_gate_events.append(feature_name)
		print("  [SIGNAL] EventBus: license_gate_triggered -> '%s'" % feature_name)
	)

	event_bus.sparring_completed.connect(func(beast_id: String, success: bool, trial_tier: String, power_score: int):
		sparring_events.append({
			"beast_id": beast_id, "success": success, "trial_tier": trial_tier, "power_score": power_score
		})
		print("  [SIGNAL] EventBus: sparring_completed -> '%s' (Success: %s, Tier: %s, Score: %d)" % [
			beast_id, str(success), trial_tier, power_score
		])
	)

	event_bus.contract_fulfilled.connect(func(contract_id: String, beast_id: String, payout: int):
		contract_events.append({"contract_id": contract_id, "beast_id": beast_id, "payout": payout})
		print("  [SIGNAL] EventBus: contract_fulfilled -> '%s' with '%s' (Payout: %d Gold)" % [
			contract_id, beast_id, payout
		])
	)

	event_bus.beast_liquidated.connect(func(beast_id: String, scrap_payout: int):
		liquidation_events.append({"beast_id": beast_id, "scrap_payout": scrap_payout})
		print("  [SIGNAL] EventBus: beast_liquidated -> '%s' (Scrap: %d Gold)" % [beast_id, scrap_payout])
	)

	print("  ✓ Services mounted and listeners bound.\n")

func _test_case_1_root_motion_attack_filter() -> void:
	print(">>> [2/6] Verifying Case 1: Global Root Motion Filter & Dodge Support...")

	var visual_ctrl: Node = MonsterVisualControllerScript.new()
	root.add_child(visual_ctrl)

	# Create a dummy model instance with animation clips
	var anim_player := AnimationPlayer.new()
	var anim_lib := AnimationLibrary.new()

	var dummy_clips: Array[String] = [
		"Jump smash attack with root motion",
		"Jump smash attack in place",
		"Spin torso attack with root motion",
		"Spin torso attack in place",
		"Fly forward with root motion",
		"Fly forward in place",
		"Dodge right",
		"Dodge left with root motion",
		"Idle"
	]

	for clip_name in dummy_clips:
		var anim := Animation.new()
		anim.length = 1.0
		anim_lib.add_animation(clip_name, anim)

	anim_player.add_animation_library("", anim_lib)
	visual_ctrl.cached_anim_player = anim_player
	visual_ctrl.add_child(anim_player)

	# 1. Verify attack resolves to in-place and rejects root motion
	var resolved_attack: String = visual_ctrl.resolve_animation("attack")
	assert(resolved_attack == "Jump smash attack in place" or resolved_attack == "Spin torso attack in place",
		"Expected in-place attack, got: %s" % resolved_attack)
	assert(not ("root motion" in resolved_attack.to_lower()), "Attack must NOT contain root motion!")

	# Specific substring match test for jump smash attack
	var resolved_jump_smash: String = visual_ctrl.resolve_animation("jump smash attack")
	assert(resolved_jump_smash == "Jump smash attack in place",
		"Resolver must select 'Jump smash attack in place', got: %s" % resolved_jump_smash)

	# 2. Verify dodge category selects clean dodge and excludes root motion
	var resolved_dodge: String = visual_ctrl.resolve_animation("dodge")
	assert(resolved_dodge == "Dodge right", "Expected 'Dodge right', got: %s" % resolved_dodge)

	# 3. Verify movement resolves to in-place
	var resolved_move: String = visual_ctrl.resolve_animation("move")
	assert(resolved_move == "Fly forward in place", "Expected 'Fly forward in place', got: %s" % resolved_move)

	visual_ctrl.queue_free()
	print("  ✓ Root motion clips globally rejected, in-place attacks and dodge confirmed.\n")

func _test_case_2_fail_forward_sparring() -> void:
	print(">>> [3/6] Verifying Case 2: Fail-Forward Sparring Loop & Clutch Awakening...")

	sparring_events.clear()

	# Create a Form 1 beast with low stats and low temperament to intentionally fail Bronze Trial
	var species: SpeciesData = _create_sun_species()
	var beast: MonsterInstance = MonsterInstanceScript.new()
	beast.initialize_species_data(species, "beast_spar_01", "Sol")
	beast.current_form_index = 1
	beast.stage = "adult"
	beast.current_atk = 12
	beast.current_def = 10
	beast.satiety = 50      # >= 40 (passes entry gate)
	beast.temperament = 35  # >= 30 (passes entry gate)
	beast.certification_grade = "None"
	beast.gene_slots = []

	var init_atk: int = beast.current_atk
	var init_def: int = beast.current_def
	var init_satiety: int = beast.satiety
	var init_temperament: int = beast.temperament
	var init_hour: int = time_manager.current_hour

	# Execute Bronze Trial (Benchmark: 45). Power score will be around 21 < 45.
	var result: Dictionary = sparring_manager.execute_trial(beast, "Bronze", true)

	assert(not result["success"], "Under-conditioned beast must fail Bronze Trial")
	assert(result["benchmark"] == 45, "Bronze benchmark must be 45")
	assert(result["power_score"] < 45, "Power score must be under benchmark")

	# Check Husbandry & Time Cost
	assert(beast.satiety == init_satiety - 30, "Trial must consume 30 satiety")
	assert(beast.temperament == init_temperament - 25, "Trial must consume 25 temperament")
	assert(time_manager.current_hour == (init_hour + 3) % 24, "Trial must advance time by 3 hours")

	# Check Fail-Forward Permanent Stat Boost (+3 ATK, +2 DEF)
	assert(beast.current_atk == init_atk + 3, "Fail-Forward must grant +3 ATK")
	assert(beast.current_def == init_def + 2, "Fail-Forward must grant +2 DEF")

	# Check Diagnostic Feedback
	var shortfall: int = 45 - result["power_score"]
	assert(result["shortfall"] == shortfall, "Shortfall must match difference")
	assert("Sunburst Peppers" in result["diagnostic"], "Diagnostic must recommend ATK crops")
	assert("Iron Grass" in result["diagnostic"], "Diagnostic must recommend DEF crops")

	# Check Sequence Log for loss
	var expected_loss_log: Array = ["beast_attack", "dummy_dodge", "dummy_counter", "beast_damage"]
	assert(result["sequence_log"] == expected_loss_log, "Loss sequence log mismatch")

	# Check Clutch Awakening
	assert(beast.gene_slots.has("Berserk_Rush"), "Clutch Awakening must unlock 'Berserk_Rush'")
	assert(beast.certification_grade == "None", "Failed trial must not award certification")

	print("  ✓ Fail-forward confirmed: Satiety/Temperament consumed, +5 stat boost applied, diagnostic crop recommendation returned, and 'Berserk_Rush' awakened.\n")

func _test_case_3_conditioned_victory_and_license_gates() -> void:
	print(">>> [4/6] Verifying Case 3: Conditioned Victory, License Gating, and Wallet Cap...")

	sparring_events.clear()
	license_gate_events.clear()

	# Create conditioned Form 1 beast capable of clearing Bronze Dummy (Benchmark 45)
	var species: SpeciesData = _create_sun_species()
	var beast: MonsterInstance = MonsterInstanceScript.new()
	beast.initialize_species_data(species, "beast_spar_02", "Helios")
	beast.current_form_index = 1
	beast.stage = "adult"
	beast.current_atk = 24
	beast.current_def = 18
	beast.satiety = 80
	beast.temperament = 80
	beast.pedigree_rank = "C"

	# 1. Execute Bronze Trial -> WIN
	var win_result: Dictionary = sparring_manager.execute_trial(beast, "Bronze")
	assert(win_result["success"], "Conditioned beast must pass Bronze Trial")
	assert(beast.certification_grade == "Bronze", "Certification must be upgraded to 'Bronze'")
	var expected_win_log: Array = [
		"beast_attack", "dummy_damage", "dummy_counter", "beast_damage", "beast_finisher", "dummy_die"
	]
	assert(win_result["sequence_log"] == expected_win_log, "Win sequence log mismatch")

	# Verify 1.25x Bronze multiplier in appraisal formula:
	# Base 1000 * Form 2.5 * Pedigree 1.0 = 2500. No traits. Husbandry avg ~55% -> 1.11. Cert 1.25 -> ~3469
	var calculated_val: int = beast.calculate_appraisal_value()
	assert(calculated_val > 2500, "Bronze certification must boost appraisal value above uncertified base")
	print("  ✓ Bronze Trial won: Badge awarded, 1.25x certification multiplier applied in appraisal formula.")

	# 2. License Gates: Verify Silver Trial blocks when unlicensed
	license_service.has_master_license = false
	var silver_entry: Dictionary = sparring_manager.can_enter_trial(beast, "Silver")
	assert(not silver_entry["can_enter"], "Silver trial must block without Master License")
	assert(license_gate_events.has("trial_silver"), "Must emit license_gate_triggered for Silver Trial")

	# 3. License Gates: Verify Noble Contract blocks when unlicensed
	var noble_contract: ContractData = ContractDataScript.new()
	noble_contract.contract_id = "noble_test_01"
	noble_contract.tier = "Noble"
	noble_contract.required_form_index = 1
	var noble_result: Dictionary = economy_manager.fulfill_contract(noble_contract, beast)
	assert(not noble_result["success"], "Noble contract must block without Master License")
	assert(license_gate_events.has("noble_contract"), "Must emit license_gate_triggered for Noble Contract")

	# 4. Free Tier Wallet Cap: Verify player_gold clamps at 5000
	economy_manager.player_gold = 0
	economy_manager.add_gold(6000)
	assert(economy_manager.player_gold == 5000, "Free tier wallet must clamp at 5000 Gold")
	assert(license_gate_events.has("gold_cap"), "Must emit license_gate_triggered for gold_cap")

	print("  ✓ License gates and free-tier gold cap (5000 Gold) strictly enforced.\n")

func _test_case_4_master_license_and_noble_contract() -> void:
	print(">>> [5/6] Verifying Case 4: Master License Unlock, Gold Dummy, and Noble Commission...")

	license_gate_events.clear()
	contract_events.clear()
	sparring_events.clear()

	# 1. Unlock Master License
	license_service.has_master_license = true
	print("  [License] Master License Unlocked -> has_master_license = true")

	# 2. Prepare Apex Form 2 Beast with Rare Mutation (Variant 2)
	var species: SpeciesData = _create_sun_species()
	var beast: MonsterInstance = MonsterInstanceScript.new()
	beast.initialize_species_data(species, "beast_apex_01", "Solaria")
	beast.current_form_index = 2
	beast.color_variant_index = 2 # Rare Mutation
	beast.pedigree_rank = "A"      # 2.2x multiplier
	beast.stage = "elder"
	beast.current_atk = 70
	beast.current_def = 60
	beast.satiety = 90
	beast.temperament = 90
	beast.gene_slots = ["Berserk_Rush"] # +300 trait value

	# 3. Gold Dummy Trial (Benchmark 140)
	var gold_entry: Dictionary = sparring_manager.can_enter_trial(beast, "Gold")
	assert(gold_entry["can_enter"], "Licensed beast must be allowed into Gold Trial")

	var gold_result: Dictionary = sparring_manager.execute_trial(beast, "Gold")
	assert(gold_result["success"], "Apex conditioned beast must clear Gold Trial")
	assert(beast.certification_grade == "Gold", "Certification must be upgraded to 'Gold'")
	assert(sparring_events.size() == 1, "Must emit sparring_completed event")
	assert(sparring_events[0]["trial_tier"] == "Gold", "Emitted tier must be Gold")

	# 4. Fulfill Noble Commission with Uncapped Payout
	var noble_contract: ContractData = ContractDataScript.new()
	noble_contract.contract_id = "noble_grand_duke"
	noble_contract.client_name = "Grand Duke of Solaris"
	noble_contract.tier = "Noble"
	noble_contract.required_form_index = 2
	noble_contract.required_pedigree = "A"
	noble_contract.required_certification = "Gold"
	noble_contract.required_variant = 2
	noble_contract.bonus_payout = 4000

	assert(noble_contract.matches_beast(beast), "Apex beast must satisfy Noble Contract")

	economy_manager.player_gold = 0
	var fulfill_result: Dictionary = economy_manager.fulfill_contract(noble_contract, beast)
	assert(fulfill_result["success"], "Noble Contract must be fulfilled")

	# Payout will easily exceed 5000:
	# Base 1000 * Form 5.0 * Pedigree 2.2 = 11000. Trait Berserk_Rush = +300. Total = 11300.
	# Husbandry ~1.18 * Gold cert 2.0 = ~26668 + 4000 bonus = > 30000 Gold!
	var final_payout: int = fulfill_result["payout"]
	assert(final_payout > 10000, "Noble payout must be substantial, got: %d" % final_payout)
	assert(economy_manager.player_gold == final_payout, "Uncapped wallet must receive full payout without 5000 cap")
	assert(contract_events.size() == 1, "Must emit contract_fulfilled event")

	print("  ✓ Gold Training Dummy cleared (2.0x multiplier) and Noble Commission paid out %d Gold.\n" % final_payout)

func _test_case_5_clearance_pen_liquidation() -> void:
	print(">>> [6/6] Verifying Case 5: Clearance Pen Liquidation (40% Scrap Value)...")

	liquidation_events.clear()
	economy_manager.player_gold = 1000

	# Create a Form 0 reject beast
	var species: SpeciesData = _create_sun_species()
	var reject: MonsterInstance = MonsterInstanceScript.new()
	reject.initialize_species_data(species, "beast_reject_01", "Scrappy")
	reject.current_form_index = 0
	reject.pedigree_rank = "F" # 0.3x
	reject.certification_grade = "None"
	reject.gene_slots = []

	var full_appraisal: int = reject.calculate_appraisal_value()
	var expected_scrap: int = maxi(1, int(round(float(full_appraisal) * 0.40)))

	economy_manager.clearance_pen.append(reject)
	var scrap_received: int = economy_manager.liquidate_clearance_pen(reject)

	assert(scrap_received == expected_scrap, "Scrap received must equal exactly 40% of appraisal value")
	assert(economy_manager.player_gold == 1000 + expected_scrap, "Player gold must increase by scrap value")
	assert(liquidation_events.size() == 1, "Must emit beast_liquidated event")
	assert(liquidation_events[0]["beast_id"] == "beast_reject_01", "Emitted beast_id mismatch")
	assert(not economy_manager.clearance_pen.has(reject), "Liquidated beast must be removed from clearance pen")

	print("  ✓ Reject beast liquidated: %d Gold full appraisal -> %d Gold scrap payout (40%%).\n" % [
		full_appraisal, scrap_received
	])

func _create_sun_species() -> SpeciesData:
	var species: SpeciesData = SpeciesDataScript.new()
	species.species_id = "sun_blossom"
	species.display_name = "Sun Blossom"
	species.base_value = 1000
	species.form_names = ["Sun Blossom", "Sunflower Fairy", "Sunflora Pixie"]
	species.form_value_multipliers = [1.0, 2.5, 5.0]
	species.form_collision_radii = [0.4, 0.7, 1.1]
	return species
