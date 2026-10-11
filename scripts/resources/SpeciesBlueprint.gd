class_name SpeciesBlueprint
extends Resource

## Static blueprint definition of a monster species.
## Encapsulates base species attributes, asset links, economic valuation, and evolution criteria.

@export_group("Identification")
@export var species_id: String = ""
@export var species_name: String = ""
@export var tier: int = 1 # Tier 1 (Common Juvenile) to Tier 5 (Legendary Monarch)
@export var element_type: String = "Neutral"

@export_group("Base Stats")
@export var base_atk: int = 10
@export var base_def: int = 10
@export var base_speed: int = 10
@export var base_max_hp: int = 100

@export_group("Tycoon Valuation")
@export var base_valuation: int = 250

@export_group("Asset References")
@export var model_path: String = ""
@export var icon_path: String = ""
@export var animation_library_path: String = ""

@export_group("Evolution Requirements")
@export var evolves_to_species_id: String = ""
@export var evolves_to_species: SpeciesBlueprint = null
@export var min_evolution_days: int = 3
@export var min_atk: int = 0
@export var min_def: int = 0
@export var min_temperament: int = 50
@export var min_satiety: int = 50
@export var required_catalytic_points: Dictionary = {}
@export var required_diet_crops: Array[String] = []
