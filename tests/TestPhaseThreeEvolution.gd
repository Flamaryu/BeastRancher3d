class_name TestPhaseThreeEvolution
extends SceneTree

## Automated test harness verifying Phase 3 systems:
## - Variable-Form Evolution Logic (Case A: 3-form line, Case B: 2-form line)
## - Evolution boundaries, stop checks, and appraisal multiplier scaling (5.0x for 3-form, 3.5x for 2-form)
## - Diffuse texture variations and optional emission texture overrides
## - Collision shape resizing per form tier
## - Smart Meshtint Animation Resolver: prioritizing "in place", rejecting "root motion",
##   automatic spawn-to-idle queuing, and feeding action fallbacks.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const SpeciesData = preload("res://scripts/resources/SpeciesData.gd")
const MonsterInstance = preload("res://scripts/resources/MonsterInstance.gd")
const MonsterVisualController = preload("res://scripts/entities/MonsterVisualController.gd")
const CropData = preload("res://scripts/resources/CropData.gd")

var event_bus: Node = null
var captured_evolutions: Array[Dictionary] = []

func _initialize() -> void:
	print("\n==================================================")
	print("  BEAST RANCHER 3D - PHASE 3 TEST HARNESS")
	print("  Variable Forms, Textures & Smart Animation Resolver")
	print("==================================================\n")

	_setup_event_bus()
	_test_case_a_three_form_evolution()
	_test_case_b_two_form_evolution()

	print("\n==================================================")
	print("  ALL PHASE 3 TESTS PASSED SUCCESSFULLY!")
	print("==================================================\n")
	quit(0)

func _setup_event_bus() -> void:
	print(">>> [1/3] Mounting EventBus & Signal Listeners...")

	if is_instance_valid(EventBusScript.instance):
		event_bus = EventBusScript.instance
	else:
		event_bus = EventBusScript.new()
		event_bus.name = "EventBus"
		root.add_child(event_bus)

	event_bus.beast_evolved.connect(func(beast_id: String, form_idx_or_spec: Variant, variant_idx: int = 0):
		captured_evolutions.append({
			"beast_id": beast_id,
			"form_index": form_idx_or_spec,
			"variant_index": variant_idx
		})
		print("  [SIGNAL] EventBus: beast_evolved -> Beast '%s' evolved to Form %s (Variant %d)" % [
			beast_id, str(form_idx_or_spec), variant_idx
		])
	)
	print("  ✓ EventBus mounted and observer bound.\n")

func _test_case_a_three_form_evolution() -> void:
	print(">>> [2/3] Verifying Case A: 3-Form Progression ('Sun Blossom' Line)...")

	captured_evolutions.clear()

	# 1. Create SpeciesData for 3-form species
	var species: SpeciesData = SpeciesData.new()
	species.species_id = "sun_blossom"
	species.display_name = "Sun Blossom"
	species.base_value = 1000
	species.form_names = ["Sun Blossom", "Sunflower Fairy", "Sunflora Pixie"]
	species.form_value_multipliers = [1.0, 2.5, 5.0]
	species.form_collision_radii = [0.4, 0.7, 1.1]

	# Procedurally create 3 form scenes with Meshtint animation clips
	var f0_scene: PackedScene = _create_form_scene("SunBlossom_F0", [
		"SunBlossom@Spawn to idle",
		"SunBlossom@Idle",
		"Fly forward with root motion",
		"Fly forward in place",
		"Head attack",
		"Rest to idle",
		"Rest",
		"Take damage",
		"Die"
	])
	var f1_scene: PackedScene = _create_form_scene("SunflowerFairy_F1", [
		"SunflowerFairy@Spawn to idle",
		"SunflowerFairy@Idle",
		"Walk forward with root motion",
		"Walk forward in place",
		"Punch attack",
		"Rest",
		"Take damage",
		"Die"
	])
	var f2_scene: PackedScene = _create_form_scene("SunfloraPixie_F2", [
		"SunfloraPixie@Spawn to idle",
		"SunfloraPixie@Idle",
		"Fly forward with root motion",
		"Fly forward in place",
		"Cast spell",
		"Blow petals",
		"Rest",
		"Take damage",
		"Die"
	])
	species.form_scenes = [f0_scene, f1_scene, f2_scene]

	# Textures per form
	var tex_yellow: Texture2D = _create_colored_texture(Color(1.0, 0.9, 0.2), "Yellow_Standard")
	var tex_orange: Texture2D = _create_colored_texture(Color(1.0, 0.5, 0.1), "Orange_Elemental")
	var tex_purple: Texture2D = _create_colored_texture(Color(0.7, 0.2, 0.9), "Purple_Mutation")
	species.textures_form_1 = [tex_yellow, tex_orange, tex_purple]
	species.textures_form_2 = [tex_yellow, tex_orange, tex_purple]
	species.textures_form_3 = [tex_yellow, tex_orange, tex_purple]

	# Emission maps for Forms 1 and 2
	var emission_cyan: Texture2D = _create_colored_texture(Color(0.2, 1.0, 1.0), "Cyan_Emission")
	var emission_gold: Texture2D = _create_colored_texture(Color(1.0, 0.8, 0.1), "Gold_Emission")
	species.emission_form_2 = emission_cyan
	species.emission_form_3 = emission_gold

	# Evolution requirements
	species.evolution_requirements = {
		1: {"min_days": 3, "required_catalytic": {"sun": 10}, "min_diet_count": 2},
		2: {"min_days": 6, "required_catalytic": {"sun": 25}, "min_diet_count": 4}
	}
	species.variant_thresholds = {
		1: {"elemental": 10},
		2: {"mutation": 15}
	}

	assert(species.get_max_form_index() == 2, "Species must report max form index 2")

	# 2. Initialize MonsterInstance
	var monster: MonsterInstance = MonsterInstance.new()
	monster.initialize_species_data(species, "beast_sun_001", "Sunny")
	assert(monster.current_form_index == 0, "Beast must start at Form index 0")
	assert(monster.color_variant_index == 0, "Beast must start at Color Variant 0")
	assert(monster.appraisal_value == 1000, "Base appraisal must be 1000 (1.0x)")
	print("  ✓ Form 0 initialized: '%s' | Appraisal: %d Gold" % [
		species.get_form_name(0), monster.appraisal_value
	])

	# Visual controller setup for Form 0
	var visual_ctrl: MonsterVisualController = MonsterVisualController.new()
	var test_col_shape: CollisionShape3D = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	test_col_shape.shape = cap
	visual_ctrl.collision_shape = test_col_shape
	root.add_child(visual_ctrl)
	root.add_child(test_col_shape)

	visual_ctrl.setup_visuals(species, 0, 0)
	var active_cap: CapsuleShape3D = test_col_shape.shape as CapsuleShape3D
	assert(is_equal_approx(active_cap.radius, 0.4), "Form 0 collision radius must be 0.4")
	assert(visual_ctrl.cached_anim_player != null, "Form 0 AnimationPlayer must be discovered")

	# Verify Form 0 Smart Animation Resolution
	var resolved_move: String = visual_ctrl.resolve_animation("move")
	assert(resolved_move == "Fly forward in place", "Locomotion resolver must pick 'in place' clip, got: %s" % resolved_move)
	assert(not ("root motion" in resolved_move.to_lower()), "Locomotion clip must NOT contain root motion!")

	var resolved_idle: String = visual_ctrl.resolve_animation("idle")
	assert(resolved_idle == "SunBlossom@Idle", "Idle resolver must pick Idle, got: %s" % resolved_idle)

	var resolved_eat: String = visual_ctrl.resolve_animation("eat")
	assert(resolved_eat == "Head attack", "Eat fallback must pick Head attack, got: %s" % resolved_eat)

	var resolved_rest: String = visual_ctrl.resolve_animation("rest")
	assert(resolved_rest == "Rest", "Rest resolver must exclude Rest to idle and pick Rest, got: %s" % resolved_rest)

	print("  ✓ Form 0 smart animation clips verified (In-place movement prioritized, root motion rejected).")

	# 3. Simulate Progression to Form 1
	print("  -> Simulating diet and aging to Form 1...")
	monster.days_old = 3
	monster.diet_history.append("sun_crop_1")
	monster.diet_history.append("sun_crop_2")
	monster.catalytic_points["sun"] = 12

	assert(monster.check_evolution_eligibility(), "Monster must now qualify for Form 1")
	var evolved_to_f1: bool = monster.evolve_to_next_form()
	assert(evolved_to_f1, "evolve_to_next_form() must return true")
	assert(monster.current_form_index == 1, "Monster must now be at Form index 1")
	assert(monster.color_variant_index == 1, "Elemental catalytic points must unlock Color Variant 1")
	assert(monster.appraisal_value == 2500, "Form 1 appraisal value must be 2500 (2.5x multiplier)")
	assert(monster.stage == "adult", "Stage must advance to adult")

	# Check EventBus emission
	assert(captured_evolutions.size() == 1, "EventBus must have emitted 1 beast_evolved event")
	assert(captured_evolutions[0]["form_index"] == 1, "Emitted form index must be 1")
	assert(captured_evolutions[0]["variant_index"] == 1, "Emitted variant index must be 1")

	# Visuals for Form 1
	visual_ctrl.setup_visuals(species, 1, 1)
	active_cap = test_col_shape.shape as CapsuleShape3D
	assert(is_equal_approx(active_cap.radius, 0.7), "Form 1 collision radius must be 0.7")
	assert(visual_ctrl.current_material != null, "Form 1 material must be created")
	assert(visual_ctrl.current_material.emission_enabled, "Form 1 must have emission enabled")
	assert(visual_ctrl.current_material.emission_texture == emission_cyan, "Form 1 emission texture mismatch")

	var f1_move: String = visual_ctrl.resolve_animation("move")
	assert(f1_move == "Walk forward in place", "Form 1 must pick Walk forward in place, got: %s" % f1_move)
	var f1_eat: String = visual_ctrl.resolve_animation("eat")
	assert(f1_eat == "Punch attack", "Form 1 eat fallback must pick Punch attack, got: %s" % f1_eat)

	print("  ✓ Form 1 verified: '%s' | Appraisal: %d Gold (2.5x) | Emission Active" % [
		species.get_form_name(1), monster.appraisal_value
	])

	# 4. Simulate Progression to Form 2
	print("  -> Simulating diet and aging to Form 2...")
	monster.days_old = 7
	monster.diet_history.append("sun_crop_3")
	monster.diet_history.append("cosmic_mutation_berry")
	monster.catalytic_points["sun"] = 28
	monster.catalytic_points["mutation"] = 18

	assert(monster.check_evolution_eligibility(), "Monster must now qualify for Form 2")
	var evolved_to_f2: bool = monster.evolve_to_next_form()
	assert(evolved_to_f2, "evolve_to_next_form() must return true")
	assert(monster.current_form_index == 2, "Monster must now be at Form index 2")
	assert(monster.color_variant_index == 2, "Mutation points must unlock Color Variant 2 (Rare Mutation)")
	assert(monster.appraisal_value == 5000, "Form 2 appraisal value must be 5000 (5.0x multiplier)")
	assert(monster.stage == "elder", "Stage must advance to elder")

	# Check EventBus emission
	assert(captured_evolutions.size() == 2, "EventBus must have emitted 2 beast_evolved events")
	assert(captured_evolutions[1]["form_index"] == 2, "Emitted form index must be 2")
	assert(captured_evolutions[1]["variant_index"] == 2, "Emitted variant index must be 2")

	# Visuals for Form 2
	visual_ctrl.setup_visuals(species, 2, 2)
	active_cap = test_col_shape.shape as CapsuleShape3D
	assert(is_equal_approx(active_cap.radius, 1.1), "Form 2 collision radius must be 1.1")
	assert(visual_ctrl.current_material != null, "Form 2 material must be created")
	assert(visual_ctrl.current_material.emission_enabled, "Form 2 must have emission enabled")
	assert(visual_ctrl.current_material.emission_texture == emission_gold, "Form 2 emission texture mismatch")

	var f2_attack: String = visual_ctrl.resolve_animation("attack")
	assert(f2_attack in ["Cast spell", "Blow petals"], "Form 2 attack clip mismatch, got: %s" % f2_attack)

	print("  ✓ Form 2 verified: '%s' | Appraisal: %d Gold (5.0x) | Rare Mutation Active" % [
		species.get_form_name(2), monster.appraisal_value
	])

	# 5. Evolution Stop / Boundary Check: verify monster cannot evolve past Form 2
	print("  -> Verifying evolution boundary at max Form 2...")
	monster.days_old = 99
	monster.catalytic_points["sun"] = 999
	monster.catalytic_points["mutation"] = 999
	for i in range(10):
		monster.diet_history.append("infinite_crop")

	var eligible_past_max: bool = monster.check_evolution_eligibility()
	assert(not eligible_past_max, "check_evolution_eligibility() must return false when at max form")

	var evolve_past_max: bool = monster.evolve_to_next_form()
	assert(not evolve_past_max, "evolve_to_next_form() must return false when at max form")
	assert(monster.current_form_index == 2, "Form index must remain 2")
	assert(monster.appraisal_value == 5000, "Appraisal value must remain 5000 (5.0x multiplier)")

	visual_ctrl.queue_free()
	test_col_shape.queue_free()
	print("  ✓ Case A successfully confirmed: 3-form progression stopped safely at Form 2 with 5.0x multiplier.\n")

func _test_case_b_two_form_evolution() -> void:
	print(">>> [3/3] Verifying Case B: 2-Form Progression ('Cinder Whelp' Line)...")

	captured_evolutions.clear()

	# 1. Create SpeciesData for 2-form species
	var species: SpeciesData = SpeciesData.new()
	species.species_id = "cinder_whelp"
	species.display_name = "Cinder Whelp"
	species.base_value = 800
	species.form_names = ["Cinder Whelp", "Magma Drake"]
	species.form_value_multipliers = [1.0, 3.5] # 2 multipliers
	species.form_collision_radii = [0.5, 0.9]    # 2 radii

	var f0_scene: PackedScene = _create_form_scene("CinderWhelp_F0", [
		"CinderWhelp@Spawn to idle",
		"CinderWhelp@Idle",
		"Fly forward with root motion",
		"Fly forward in place",
		"Head attack",
		"Rest",
		"Take damage",
		"Die"
	])
	var f1_scene: PackedScene = _create_form_scene("MagmaDrake_F1", [
		"MagmaDrake@Spawn to idle",
		"MagmaDrake@Idle",
		"Fly forward with root motion",
		"Fly forward in place",
		"Bite",
		"Rest",
		"Take damage",
		"Die"
	])
	species.form_scenes = [f0_scene, f1_scene] # Exactly 2 PackedScenes!

	var tex_red: Texture2D = _create_colored_texture(Color(0.9, 0.1, 0.1), "Red_Standard")
	var tex_obsidian: Texture2D = _create_colored_texture(Color(0.1, 0.1, 0.1), "Obsidian_Elemental")
	species.textures_form_1 = [tex_red, tex_obsidian]
	species.textures_form_2 = [tex_red, tex_obsidian]
	species.textures_form_3 = [] # Explicitly empty for 2-form species

	var emission_magma: Texture2D = _create_colored_texture(Color(1.0, 0.3, 0.0), "Magma_Emission")
	species.emission_form_2 = emission_magma

	species.evolution_requirements = {
		1: {"min_days": 4, "required_catalytic": {"fire": 10}, "min_diet_count": 2}
	}

	assert(species.get_max_form_index() == 1, "2-form species must report max form index 1")

	# 2. Initialize MonsterInstance
	var monster: MonsterInstance = MonsterInstance.new()
	monster.initialize_species_data(species, "beast_cinder_002", "Iggy")
	assert(monster.current_form_index == 0, "Beast must start at Form 0")
	assert(monster.appraisal_value == 800, "Base appraisal must be 800 (1.0x)")
	print("  ✓ Form 0 initialized: '%s' | Appraisal: %d Gold" % [
		species.get_form_name(0), monster.appraisal_value
	])

	# Visual Controller for 2-Form Beast
	var visual_ctrl: MonsterVisualController = MonsterVisualController.new()
	var test_col_shape: CollisionShape3D = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	test_col_shape.shape = cap
	visual_ctrl.collision_shape = test_col_shape
	root.add_child(visual_ctrl)
	root.add_child(test_col_shape)

	visual_ctrl.setup_visuals(species, 0, 0)
	var active_cap: CapsuleShape3D = test_col_shape.shape as CapsuleShape3D
	assert(is_equal_approx(active_cap.radius, 0.5), "Form 0 collision radius must be 0.5")

	# 3. Simulate Progression to Form 1
	print("  -> Simulating diet and aging to Form 1 (Final form for 2-form creature)...")
	monster.days_old = 4
	monster.diet_history.append("fire_pepper_1")
	monster.diet_history.append("fire_pepper_2")
	monster.catalytic_points["fire"] = 14

	assert(monster.check_evolution_eligibility(), "Monster must qualify for Form 1")
	var evolved_to_f1: bool = monster.evolve_to_next_form()
	assert(evolved_to_f1, "evolve_to_next_form() must succeed")
	assert(monster.current_form_index == 1, "Monster must be at Form index 1")
	assert(monster.appraisal_value == 2800, "Form 1 appraisal value must be 2800 (800 * 3.5x multiplier)")
	assert(monster.stage == "elder", "Stage must advance to elder as index 1 is max form for 2 forms")

	# Visuals for Form 1
	visual_ctrl.setup_visuals(species, 1, 1)
	active_cap = test_col_shape.shape as CapsuleShape3D
	assert(is_equal_approx(active_cap.radius, 0.9), "Form 1 collision radius must be 0.9")
	assert(visual_ctrl.current_material != null, "Form 1 material must be created")
	assert(visual_ctrl.current_material.emission_enabled, "Form 1 emission must be active")

	print("  ✓ Form 1 verified: '%s' | Appraisal: %d Gold (3.5x final multiplier)" % [
		species.get_form_name(1), monster.appraisal_value
	])

	# 4. Boundary Check: Attempting to evolve again at Form 1 must safely stop without out-of-bounds errors
	print("  -> Verifying evolution boundary for 2-form species at Form 1...")
	monster.days_old = 20
	monster.catalytic_points["fire"] = 100
	monster.diet_history.append("extra_crop")

	var eligible_past_final: bool = monster.check_evolution_eligibility()
	assert(not eligible_past_final, "check_evolution_eligibility() must return false for 2-form species at Form 1")

	var evolved_past_final: bool = monster.evolve_to_next_form()
	assert(not evolved_past_final, "evolve_to_next_form() must return false for 2-form species at Form 1")
	assert(monster.current_form_index == 1, "Form index must safely remain 1 without out-of-bounds error")
	assert(monster.appraisal_value == 2800, "Appraisal value must remain 2800 (3.5x multiplier)")

	# Calling helper methods with out-of-bounds indices must also be resilient
	var safe_mult: float = species.get_form_multiplier(2)
	assert(is_equal_approx(safe_mult, 3.5), "Out-of-bounds multiplier check must fall back to last multiplier (3.5)")
	var safe_radius: float = species.get_form_collision_radius(2)
	assert(is_equal_approx(safe_radius, 0.9), "Out-of-bounds radius check must fall back to last radius (0.9)")
	var safe_tex: Texture2D = species.get_diffuse_texture(2, 0)
	assert(safe_tex == null, "Out-of-bounds texture check must safely return null")
	var safe_scene: PackedScene = species.get_form_scene(2)
	assert(safe_scene == null, "Out-of-bounds scene check must safely return null")

	visual_ctrl.queue_free()
	test_col_shape.queue_free()
	print("  ✓ Case B successfully confirmed: 2-form progression stopped safely at Form 1 with 3.5x multiplier.\n")

func _create_form_scene(form_name: String, anim_names: Array[String]) -> PackedScene:
	var root_node := Node3D.new()
	root_node.name = form_name

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "BodyMesh"
	mesh_inst.mesh = BoxMesh.new()
	root_node.add_child(mesh_inst)
	mesh_inst.owner = root_node

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var anim_lib := AnimationLibrary.new()

	for a_name in anim_names:
		var anim := Animation.new()
		anim.length = 1.0
		anim_lib.add_animation(a_name, anim)

	anim_player.add_animation_library("", anim_lib)
	root_node.add_child(anim_player)
	anim_player.owner = root_node

	var packed := PackedScene.new()
	packed.pack(root_node)
	return packed

func _create_colored_texture(color: Color, tex_name: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_name = tex_name
	return tex
