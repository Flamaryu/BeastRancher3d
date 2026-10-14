extends Node

## Global signal manager for decoupled game architecture.
## Follows the Observer pattern to synchronize game loop, monsters, economy, and UI.

# --- Time & Simulation Signals ---
signal day_ticked(current_day: int)
signal hour_ticked(current_hour: int)
signal tick_speed_changed(multiplier: float)

# --- Monster & Husbandry Signals ---
signal beast_fed(beast_id: String, crop_id: String)
signal beast_evolved(beast_id: String, form_or_species_id: Variant, color_variant_index: int)
signal beast_appraised(beast_id: String, calculated_value: int)

# --- Mobile Interaction & Selection Signals ---
signal monster_selected(monster_data: MonsterInstance)
signal monster_deselected()
signal feed_requested(monster_data: MonsterInstance, crop: CropData)

# --- Spatial Grid & Farm Signals ---
signal cell_state_changed(grid_pos: Vector2i, cell_type: int, occupant_id: String)

static var instance: Node = null

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null
