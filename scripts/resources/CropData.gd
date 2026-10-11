class_name CropData
extends Resource

## Data definition for crops grown on farm plots and fed to beasts.
## Provides nutrition, husbandry restoration, permanent stat gains, and evolution catalysts.

@export var crop_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var growth_duration_days: int = 1

# Nutritional stat modifiers
@export var atk_modifier: int = 0
@export var def_modifier: int = 0
@export var speed_modifier: int = 0
@export var max_hp_modifier: int = 0

# Husbandry restoration
@export var satiety_restoration: int = 25
@export var hygiene_modifier: int = 0
@export var temperament_modifier: int = 5

# Catalytic points keyed by evolution catalyst / element (e.g., {"fire": 5, "dragon": 2})
@export var evolution_catalytic_points: Dictionary = {}

# Economy & Assets
@export var base_sell_price: int = 15
@export var icon_path: String = ""
@export var model_path: String = ""
