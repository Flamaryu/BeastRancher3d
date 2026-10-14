class_name ContractData
extends Resource

## Data resource representing client contracts (Guild, Caravan, Noble Outpost commissions).
## Specifies target beast criteria, certification/pedigree requirements, and bonus payouts.

const MonsterInstance = preload("res://scripts/resources/MonsterInstance.gd")

const PEDIGREE_ORDER = ["F", "E", "D", "C", "B", "A", "S"]

@export_group("Contract Identification")
@export var contract_id: String = ""
@export var client_name: String = ""
@export var tier: String = "Guild" # "Guild", "Caravan", "Noble"

@export_group("Beast Specifications")
@export var required_form_index: int = 0
@export var required_pedigree: String = "" # e.g. "C", "B", "A", "S"
@export var required_certification: String = "" # e.g. "Bronze", "Silver", "Gold"
@export var required_variant: int = -1 # -1: Any, 0: Standard, 1: Elemental, 2: Mutation

@export_group("Economic Reward")
@export var bonus_payout: int = 500
@export var is_fulfilled: bool = false

## Evaluates whether the candidate monster satisfies all client criteria.
func matches_beast(monster: MonsterInstance) -> bool:
	if monster == null:
		return false

	# 1. Form Progression Check
	if monster.current_form_index < required_form_index:
		return false

	# 2. Pedigree Rank Check
	if not required_pedigree.is_empty():
		var req_p_idx: int = PEDIGREE_ORDER.find(required_pedigree.to_upper())
		var beast_p_idx: int = PEDIGREE_ORDER.find(monster.pedigree_rank.to_upper())
		if req_p_idx != -1 and beast_p_idx < req_p_idx:
			return false

	# 3. Certification Tier Check
	if not required_certification.is_empty():
		var req_c_rank: int = _cert_to_rank(required_certification)
		var beast_c_rank: int = _cert_to_rank(monster.certification_grade)
		if beast_c_rank < req_c_rank:
			return false

	# 4. Color Variant Check
	if required_variant >= 0:
		if monster.color_variant_index < required_variant:
			return false

	return true

## Calculates the contract payout: beast appraisal value plus contract bonus.
func calculate_payout(monster: MonsterInstance) -> int:
	if monster == null:
		return bonus_payout
	return monster.calculate_appraisal_value() + bonus_payout

func _cert_to_rank(cert: String) -> int:
	match cert.to_lower():
		"bronze", "standard":
			return 1
		"silver", "elite":
			return 2
		"gold", "master":
			return 3
		_:
			return 0
