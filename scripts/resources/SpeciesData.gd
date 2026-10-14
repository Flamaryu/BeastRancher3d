class_name SpeciesData
extends Resource

## Data resource defining multi-form beast species configuration.
## Supports variable evolution forms (2 or 3 forms), diffuse/emission texture variants,
## and collision/economic scaling per form.

@export_group("Identification")
@export var species_id: String = ""
@export var display_name: String = ""
@export var base_value: int = 1000

@export_group("Form Progression")
## PackedScenes for each evolution form (supports 2 or 3 forms).
@export var form_scenes: Array[PackedScene] = []
## Display names for each form tier (e.g. ["Sun Blossom", "Sunflower Fairy", "Sunflora Pixie"]).
@export var form_names: Array[String] = []
## Valuation multipliers per form (e.g. [1.0, 2.5, 5.0] for 3 forms, [1.0, 3.5] for 2 forms).
@export var form_value_multipliers: Array[float] = [1.0, 2.5, 5.0]
## Collision shape radii per form tier (e.g. [0.4, 0.7, 1.1]).
@export var form_collision_radii: Array[float] = [0.4, 0.7, 1.1]

@export_group("Diffuse Texture Variations")
## Form 1 diffuse variants (Index 0: Standard, Index 1: Elemental, Index 2: Mutation).
@export var textures_form_1: Array[Texture2D] = []
## Form 2 diffuse variants.
@export var textures_form_2: Array[Texture2D] = []
## Form 3 diffuse variants.
@export var textures_form_3: Array[Texture2D] = []

@export_group("Emission Texture Maps")
## Optional emission map for Form 1.
@export var emission_form_1: Texture2D = null
## Optional emission map for Form 2.
@export var emission_form_2: Texture2D = null
## Optional emission map for Form 3.
@export var emission_form_3: Texture2D = null

@export_group("Evolution Requirements")
## Evolution thresholds per target form index (e.g. { 1: {"min_days": 3, "required_catalytic": {"sun": 10}}, 2: {"min_days": 6} }).
@export var evolution_requirements: Dictionary = {}
## Optional color variant unlock thresholds (e.g. { 1: {"elemental": 10}, 2: {"mutation": 15} }).
@export var variant_thresholds: Dictionary = {
	1: {"elemental": 10},
	2: {"mutation": 15}
}

## Returns the maximum reachable form index (form_scenes.size() - 1).
func get_max_form_index() -> int:
	if form_scenes.is_empty():
		return 0
	return form_scenes.size() - 1

## Resolves the diffuse texture for the given form index and color variant index.
## Safely falls back to index 0 (standard) if the requested variant is not configured.
func get_diffuse_texture(form_idx: int, color_idx: int) -> Texture2D:
	var list: Array[Texture2D] = _get_texture_list_for_form(form_idx)
	if list.is_empty():
		return null
	
	if color_idx >= 0 and color_idx < list.size() and list[color_idx] != null:
		return list[color_idx]
	
	# Fallback to standard variant (index 0)
	if not list.is_empty() and list[0] != null:
		return list[0]
	
	return null

## Resolves the emission texture map for the given form index if configured.
func get_emission_texture(form_idx: int) -> Texture2D:
	match form_idx:
		0:
			return emission_form_1
		1:
			return emission_form_2
		2:
			return emission_form_3
		_:
			return null

## Returns the valuation multiplier for the given form index.
func get_form_multiplier(form_idx: int) -> float:
	if form_idx >= 0 and form_idx < form_value_multipliers.size():
		return form_value_multipliers[form_idx]
	elif not form_value_multipliers.is_empty():
		return form_value_multipliers[form_value_multipliers.size() - 1]
	return 1.0

## Returns the collision radius for the given form index.
func get_form_collision_radius(form_idx: int) -> float:
	if form_idx >= 0 and form_idx < form_collision_radii.size():
		return form_collision_radii[form_idx]
	elif not form_collision_radii.is_empty():
		return form_collision_radii[form_collision_radii.size() - 1]
	return 0.5

## Returns the display name for the given form index.
func get_form_name(form_idx: int) -> String:
	if form_idx >= 0 and form_idx < form_names.size() and not form_names[form_idx].is_empty():
		return form_names[form_idx]
	if not display_name.is_empty():
		return "%s (Tier %d)" % [display_name, form_idx + 1]
	return "Form %d" % form_idx

## Returns the PackedScene for the given form index.
func get_form_scene(form_idx: int) -> PackedScene:
	if form_idx >= 0 and form_idx < form_scenes.size():
		return form_scenes[form_idx]
	return null

## Returns the requirement dictionary for evolving into target_form_idx.
func get_evolution_requirement(target_form_idx: int) -> Dictionary:
	if evolution_requirements.has(target_form_idx):
		return evolution_requirements[target_form_idx]
	# Support string key if dictionary was deserialized with string keys
	var str_key: String = str(target_form_idx)
	if evolution_requirements.has(str_key):
		return evolution_requirements[str_key]
	return {}

func _get_texture_list_for_form(form_idx: int) -> Array[Texture2D]:
	match form_idx:
		0:
			return textures_form_1
		1:
			return textures_form_2
		2:
			return textures_form_3
		_:
			return []
