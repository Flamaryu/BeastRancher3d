class_name MonsterVisualController
extends Node3D

## Visual & Animation Controller for Meshtint 3D Beast models.
## Manages dynamic multi-form instantiation, diffuse/emission texture overrides,
## collision radius synchronization, and smart animation clip resolution (prioritizing
## in-place locomotion and rejecting root motion).

const SpeciesData = preload("res://scripts/resources/SpeciesData.gd")

@export_group("Component Bindings")
## Container node holding the active 3D model instance.
@export var mesh_anchor: Node3D = null
## Reference to the entity's physical collision shape to resize per form tier.
@export var collision_shape: CollisionShape3D = null

var cached_anim_player: AnimationPlayer = null
var current_model_instance: Node = null
var current_material: StandardMaterial3D = null
var active_species: SpeciesData = null
var active_form_index: int = 0
var active_color_index: int = 0

func _ready() -> void:
	_ensure_mesh_anchor()

func _ensure_mesh_anchor() -> void:
	if mesh_anchor == null:
		mesh_anchor = get_node_or_null("MeshAnchor")
	if mesh_anchor == null:
		mesh_anchor = Node3D.new()
		mesh_anchor.name = "MeshAnchor"
		add_child(mesh_anchor)

## Sets up visuals for a species at a given form tier and color variant.
## Instantiates the form's PackedScene, applies texture & emission overrides,
## resizes collision shape, caches AnimationPlayer, and triggers the spawn animation.
func setup_visuals(species: SpeciesData, form_idx: int, color_idx: int) -> void:
	active_species = species
	active_form_index = form_idx
	active_color_index = color_idx

	_ensure_mesh_anchor()

	# 1. Safely remove previous form's 3D node
	if current_model_instance != null and is_instance_valid(current_model_instance):
		current_model_instance.queue_free()
		current_model_instance = null
	
	# Clean any residual children inside mesh_anchor
	for child in mesh_anchor.get_children():
		child.queue_free()

	cached_anim_player = null
	current_material = null

	if species == null:
		return

	# 2. Instantiate new form scene
	var scene: PackedScene = species.get_form_scene(form_idx)
	if scene != null:
		current_model_instance = scene.instantiate()
		mesh_anchor.add_child(current_model_instance)
		cached_anim_player = _find_animation_player(current_model_instance)

	# 3. Apply StandardMaterial3D override with diffuse variant and optional emission map
	var diffuse_tex: Texture2D = species.get_diffuse_texture(form_idx, color_idx)
	var emission_tex: Texture2D = species.get_emission_texture(form_idx)

	if diffuse_tex != null or emission_tex != null:
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Mat_%s_F%d_C%d" % [species.species_id, form_idx, color_idx]
		if diffuse_tex != null:
			mat.albedo_texture = diffuse_tex
		if emission_tex != null:
			mat.emission_enabled = true
			mat.emission_texture = emission_tex
			mat.emission = Color(1.0, 1.0, 1.0)
			mat.emission_energy_multiplier = 1.2
		current_material = mat
		if current_model_instance != null:
			_apply_material_override(current_model_instance, mat)

	# 4. Resize CollisionShape3D based on form collision radius
	var radius: float = species.get_form_collision_radius(form_idx)
	_update_collision_shape_radius(radius)

	# 5. Play "spawn" animation automatically and queue "idle"
	play_smart_animation("spawn")

## Resolves an abstract action category into the best matching Meshtint clip name.
## Explicitly prioritizes "in place" locomotion and REJECTS clips containing "root motion".
func resolve_animation(action_category: String) -> String:
	if cached_anim_player == null:
		return ""

	var anim_list: PackedStringArray = cached_anim_player.get_animation_list()
	if anim_list.is_empty():
		return ""

	var cat: String = action_category.to_lower().strip_edges()

	match cat:
		"spawn":
			# Matches ["spawn to idle", "spawn"]
			for target in ["spawn to idle", "spawn"]:
				for anim in anim_list:
					var l_anim: String = anim.to_lower()
					if target in l_anim:
						return anim

		"idle":
			# Matches ["idle", "look around"], strictly excluding "spawn" and "rest to idle"
			var idle_candidates: Array[String] = []
			var look_candidates: Array[String] = []
			for anim in anim_list:
				var l_anim: String = anim.to_lower()
				# Exclude clips containing spawn, rest to idle, or root motion
				if "spawn" in l_anim or "rest to idle" in l_anim:
					continue
				if "root motion" in l_anim or "w root" in l_anim:
					continue

				if "idle" in l_anim:
					idle_candidates.append(anim)
				elif "look around" in l_anim:
					look_candidates.append(anim)

			if not idle_candidates.is_empty():
				return idle_candidates[0]
			if not look_candidates.is_empty():
				return look_candidates[0]

		"move", "walk", "run":
			# Meshtint models include both "in place" and "with root motion" clips.
			# MUST explicitly reject any animation name containing "root motion".
			# Prioritize "in place" clips first.
			var in_place_candidates: Array[String] = []
			var generic_move_candidates: Array[String] = []

			for anim in anim_list:
				var l_anim: String = anim.to_lower()
				# Explicit rejection of root motion
				if "root motion" in l_anim or "w root" in l_anim:
					continue

				if "in place" in l_anim:
					in_place_candidates.append(anim)
				elif "walk" in l_anim or "run" in l_anim or "fly forward" in l_anim or "move" in l_anim:
					generic_move_candidates.append(anim)

			if not in_place_candidates.is_empty():
				return in_place_candidates[0]
			if not generic_move_candidates.is_empty():
				return generic_move_candidates[0]

		"eat":
			# Feeding action fallback: ["eat", "head attack", "punch attack", "bite", "cast spell"]
			for target in ["eat", "bite", "head attack", "punch attack", "cast spell"]:
				for anim in anim_list:
					var l_anim: String = anim.to_lower()
					if "root motion" in l_anim or "w root" in l_anim:
						continue
					if target in l_anim:
						return anim

		"rest":
			# Matches ["rest"], strictly excluding "rest to idle" and "spawn to rest"
			for anim in anim_list:
				var l_anim: String = anim.to_lower()
				if "rest to idle" in l_anim or "spawn to rest" in l_anim:
					continue
				if "root motion" in l_anim or "w root" in l_anim:
					continue
				if "rest" in l_anim:
					return anim

		"attack":
			# Available attack/spell clips: ["attack", "spell", "blow petals"]
			for target in ["attack", "spell", "blow petals"]:
				for anim in anim_list:
					var l_anim: String = anim.to_lower()
					if "root motion" in l_anim or "w root" in l_anim:
						continue
					if target in l_anim:
						return anim

		"damage", "hit":
			# Matches ["take damage", "hit", "damage"]
			for target in ["take damage", "hit", "damage"]:
				for anim in anim_list:
					var l_anim: String = anim.to_lower()
					if "root motion" in l_anim or "w root" in l_anim:
						continue
					if target in l_anim:
						return anim

		"die", "death":
			# Matches ["die", "death"]
			for target in ["die", "death"]:
				for anim in anim_list:
					var l_anim: String = anim.to_lower()
					if target in l_anim:
						return anim

		_:
			# General fallback: substring match ignoring root motion
			for anim in anim_list:
				var l_anim: String = anim.to_lower()
				if "root motion" in l_anim or "w root" in l_anim:
					continue
				if cat in l_anim:
					return anim

	return ""

## Plays the resolved animation clip on the cached AnimationPlayer.
## When "spawn" is played, automatically queues "idle" to follow smoothly.
func play_smart_animation(action_category: String) -> void:
	if cached_anim_player == null:
		return

	var resolved_clip: String = resolve_animation(action_category)
	if resolved_clip.is_empty():
		return

	cached_anim_player.play(resolved_clip)

	# When playing spawn, automatically queue idle if available
	if action_category.to_lower() == "spawn":
		var idle_clip: String = resolve_animation("idle")
		if not idle_clip.is_empty() and idle_clip != resolved_clip:
			cached_anim_player.queue(idle_clip)

func _update_collision_shape_radius(radius: float) -> void:
	if collision_shape == null:
		collision_shape = get_node_or_null("../CollisionShape3D")
	if collision_shape == null:
		return

	if collision_shape.shape is CapsuleShape3D:
		var cap := collision_shape.shape as CapsuleShape3D
		cap.height = maxf(radius * 2.5, cap.height)
		cap.radius = radius
	elif collision_shape.shape is SphereShape3D:
		var sph := collision_shape.shape as SphereShape3D
		sph.radius = radius
	elif collision_shape.shape is CylinderShape3D:
		var cyl := collision_shape.shape as CylinderShape3D
		cyl.height = maxf(radius * 2.5, cyl.height)
		cyl.radius = radius
	elif collision_shape.shape == null:
		var cap := CapsuleShape3D.new()
		cap.height = radius * 2.5
		cap.radius = radius
		collision_shape.shape = cap

func _apply_material_override(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material_override(child, mat)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null
