extends Node

## Store and Entitlement service managing feature gating, monetization limits,
## and DLC licensing (Free Tier vs. Master License vs. Clockwork DLC).

const EventBusScript = preload("res://scripts/core/EventBus.gd")

const FREE_TIER_GOLD_CAP: int = 5000

@export var has_master_license: bool = false
@export var has_clockwork_dlc: bool = false

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

## Checks if the player's current entitlement grants access to a sparring trial tier.
## Bronze (Practice Dummy) is free tier accessible; Silver and Gold require Master License.
func can_access_trial(trial_tier: String) -> bool:
	match trial_tier.to_lower():
		"bronze", "practice", "form_0":
			return true
		"silver", "target", "form_1", "gold", "training", "form_2":
			if has_master_license:
				return true
			notify_license_gate("trial_" + trial_tier.to_lower())
			return false
		_:
			return true

## Checks if the player's entitlement permits fulfilling a contract tier.
## Guild and Caravan contracts are accessible in Free Tier; Noble contracts require Master License.
func can_access_contract(contract_tier: String) -> bool:
	match contract_tier.to_lower():
		"guild", "caravan":
			return true
		"noble":
			if has_master_license:
				return true
			notify_license_gate("noble_contract")
			return false
		_:
			return true

## Clamps raw gold to FREE_TIER_GOLD_CAP if player does not own Master License.
func get_effective_gold(raw_gold: int) -> int:
	if has_master_license:
		return raw_gold
	return mini(FREE_TIER_GOLD_CAP, raw_gold)

## Emits license_gate_triggered on the EventBus.
func notify_license_gate(feature_name: String) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("license_gate_triggered"):
		bus.license_gate_triggered.emit(feature_name)

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
