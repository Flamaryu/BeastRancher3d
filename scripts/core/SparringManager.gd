extends Node

## 3-Tier Dummy Sparring Ring Manager with Fail-Forward Mechanics.
## Manages trial entry gates, stat training fail-forward progression,
## license gating for Silver/Gold tiers, and clutch trait awakenings.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const LicenseServiceScript = preload("res://scripts/core/LicenseService.gd")
const TimeManagerScript = preload("res://scripts/core/TimeManager.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")

const TRIALS: Dictionary = {
	"bronze": {
		"name": "Practice Dummy",
		"form_index": 0,
		"benchmark": 45,
		"multiplier": 1.25,
		"certification": "Bronze",
		"requires_license": false
	},
	"silver": {
		"name": "Target Dummy",
		"form_index": 1,
		"benchmark": 85,
		"multiplier": 1.50,
		"certification": "Silver",
		"requires_license": true
	},
	"gold": {
		"name": "Training Dummy",
		"form_index": 2,
		"benchmark": 140,
		"multiplier": 2.00,
		"certification": "Gold",
		"requires_license": true
	}
}

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

## Evaluates whether the beast meets husbandry entry conditions and license gating for the trial tier.
func can_enter_trial(beast: MonsterInstance, trial_tier: String) -> Dictionary:
	if beast == null:
		return {"can_enter": false, "reason": "No beast specified."}

	var tier_key: String = trial_tier.to_lower()
	if not TRIALS.has(tier_key):
		return {"can_enter": false, "reason": "Unknown trial tier '%s'." % trial_tier}

	var trial_cfg: Dictionary = TRIALS[tier_key]

	# 1. License Check
	if trial_cfg.requires_license:
		var license: LicenseService = _get_license_service()
		if license != null and not license.can_access_trial(tier_key):
			return {
				"can_enter": false,
				"reason": "%s Trial requires Master License." % trial_cfg.certification,
				"license_blocked": true
			}

	# 2. Maturity Gate (Must be Form 1 or higher)
	if beast.current_form_index < 1:
		return {
			"can_enter": false,
			"reason": "Beast is too young for combat sparring (requires Form 1+)."
		}

	# 3. Husbandry Entry Gate (Satiety >= 40, Temperament >= 30)
	if beast.satiety < 40 or beast.temperament < 30:
		return {
			"can_enter": false,
			"reason": "Beast lacks condition (requires Satiety >= 40 and Temperament >= 30)."
		}

	return {"can_enter": true, "reason": "Eligible"}

## Calculates the combat power score: (ATK + DEF) scaled by temperament reliability factor.
func calculate_power_score(beast: MonsterInstance) -> int:
	if beast == null:
		return 0
	var base_stat: float = float(beast.current_atk + beast.current_def)
	var reliability: float = 0.7 + (float(beast.temperament) / 100.0) * 0.5
	return int(round(base_stat * reliability))

## Executes a sparring match against the designated Dummy trial.
## Handles entry gate deduction, time advancement, win progression, and fail-forward stat boosts.
func execute_trial(beast: MonsterInstance, trial_tier: String, force_clutch_awakening: bool = false) -> Dictionary:
	var entry_check: Dictionary = can_enter_trial(beast, trial_tier)
	if not entry_check.get("can_enter", false):
		return {
			"success": false,
			"reason": entry_check.get("reason", "Cannot enter trial"),
			"license_blocked": entry_check.get("license_blocked", false),
			"sequence_log": []
		}

	var tier_key: String = trial_tier.to_lower()
	var trial_cfg: Dictionary = TRIALS[tier_key]
	var benchmark: int = trial_cfg.benchmark
	var cert_grade: String = trial_cfg.certification

	# Calculate combat performance based on beast's entering husbandry condition
	var power_score: int = calculate_power_score(beast)

	# Consume Husbandry & Time Cost:
	# 30 satiety, 25 temperament, advances clock by 3 hours
	beast.satiety = clampi(beast.satiety - 30, 0, 100)
	beast.temperament = clampi(beast.temperament - 25, 0, 100)

	var tm: Node = _get_time_manager()
	if tm != null and tm.has_method("advance_hours"):
		tm.advance_hours(3)

	var bus: Node = _get_event_bus()

	# --- WIN RESOLUTION ---
	if power_score >= benchmark:
		beast.certification_grade = cert_grade

		# 5% chance to awaken Berserk_Rush (or if force_clutch_awakening)
		var trait_awakened: String = ""
		var roll: float = randf()
		if (roll <= 0.05 or force_clutch_awakening) and not beast.gene_slots.has("Berserk_Rush"):
			beast.gene_slots.append("Berserk_Rush")
			trait_awakened = "Berserk_Rush"

		beast.calculate_appraisal_value()

		if bus != null and bus.has_signal("sparring_completed"):
			bus.sparring_completed.emit(beast.beast_id, true, cert_grade, power_score)

		var win_log: Array[String] = [
			"beast_attack", "dummy_damage", "dummy_counter", "beast_damage", "beast_finisher", "dummy_die"
		]

		return {
			"success": true,
			"trial_tier": cert_grade,
			"power_score": power_score,
			"benchmark": benchmark,
			"certification_granted": cert_grade,
			"trait_awakened": trait_awakened,
			"sequence_log": win_log,
			"message": "Victory! %s cleared with power score %d / %d." % [trial_cfg.name, power_score, benchmark]
		}

	# --- FAIL-FORWARD RESOLUTION ---
	else:
		# 1. Fail-Forward Stat Boost: Permanent +5 stats (+3 ATK, +2 DEF)
		beast.current_atk += 3
		beast.current_def += 2

		# 2. Clutch Awakening: 10% chance to awaken Berserk_Rush
		var trait_awakened: String = ""
		var clutch_roll: float = randf()
		if (clutch_roll <= 0.10 or force_clutch_awakening) and not beast.gene_slots.has("Berserk_Rush"):
			beast.gene_slots.append("Berserk_Rush")
			trait_awakened = "Berserk_Rush"

		beast.calculate_appraisal_value()

		if bus != null and bus.has_signal("sparring_completed"):
			bus.sparring_completed.emit(beast.beast_id, false, cert_grade, power_score)

		var shortfall: int = benchmark - power_score
		var diagnostic_msg: String = "Defeat! Power Score %d / %d (Short by %d). Recommend feeding Sunburst Peppers (ATK) or Iron Grass (DEF) to condition your beast." % [
			power_score, benchmark, shortfall
		]

		var loss_log: Array[String] = [
			"beast_attack", "dummy_dodge", "dummy_counter", "beast_damage"
		]

		return {
			"success": false,
			"trial_tier": cert_grade,
			"power_score": power_score,
			"benchmark": benchmark,
			"shortfall": shortfall,
			"fail_forward_boost": {"atk": 3, "def": 2},
			"trait_awakened": trait_awakened,
			"diagnostic": diagnostic_msg,
			"sequence_log": loss_log,
			"message": diagnostic_msg
		}

func _get_license_service() -> Node:
	if is_instance_valid(LicenseServiceScript.instance):
		return LicenseServiceScript.instance
	if is_inside_tree() and has_node("/root/LicenseService"):
		return get_node("/root/LicenseService")
	return null

func _get_time_manager() -> Node:
	if is_instance_valid(TimeManagerScript.instance):
		return TimeManagerScript.instance
	if is_inside_tree() and has_node("/root/TimeManager"):
		return get_node("/root/TimeManager")
	return null

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
