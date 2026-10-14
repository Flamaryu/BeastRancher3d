extends Node

## Economy and merchant tycoon manager.
## Handles player wallet, daily client contracts (Guild, Caravan, Noble),
## store license limits, and Clearance Pen liquidation (40% scrap scrap value).

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const LicenseServiceScript = preload("res://scripts/core/LicenseService.gd")
const ContractDataScript = preload("res://scripts/resources/ContractData.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")

@export var player_gold: int = 0
@export var active_contracts: Array[ContractData] = []
@export var clearance_pen: Array[MonsterInstance] = []

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

## Adds gold to player wallet, subject to LicenseService Free Tier gold cap.
func add_gold(amount: int) -> int:
	if amount <= 0:
		return player_gold

	var license: LicenseService = _get_license_service()
	if license != null and not license.has_master_license:
		var cap: int = LicenseService.FREE_TIER_GOLD_CAP
		if player_gold + amount >= cap:
			player_gold = cap
			license.notify_license_gate("gold_cap")
		else:
			player_gold += amount
	else:
		player_gold += amount

	return player_gold

## Spends gold if player possesses sufficient funds.
func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if player_gold >= amount:
		player_gold -= amount
		return true
	return false

## Generates daily contract commissions for Guild, Caravan, and Noble clients.
func generate_daily_contracts(day: int = 1) -> Array[ContractData]:
	active_contracts.clear()

	# 1. Guild Outpost Contract (Low requirement)
	var guild_contract: ContractData = ContractDataScript.new()
	guild_contract.contract_id = "contract_guild_%d" % day
	guild_contract.client_name = "Frontier Outpost Guild"
	guild_contract.tier = "Guild"
	guild_contract.required_form_index = 0
	guild_contract.bonus_payout = 250
	active_contracts.append(guild_contract)

	# 2. Caravan Merchant Contract (Mid requirement)
	var caravan_contract: ContractData = ContractDataScript.new()
	caravan_contract.contract_id = "contract_caravan_%d" % day
	caravan_contract.client_name = "Desert Silk Caravan"
	caravan_contract.tier = "Caravan"
	caravan_contract.required_form_index = 1
	caravan_contract.required_certification = "Bronze"
	caravan_contract.bonus_payout = 750
	active_contracts.append(caravan_contract)

	# 3. Noble Commission (High requirement - Master License Gated)
	var noble_contract: ContractData = ContractDataScript.new()
	noble_contract.contract_id = "contract_noble_%d" % day
	noble_contract.client_name = "Grand Duke of Solaris"
	noble_contract.tier = "Noble"
	noble_contract.required_form_index = 2
	noble_contract.required_pedigree = "A"
	noble_contract.required_certification = "Gold"
	noble_contract.required_variant = 2 # Rare Mutation
	noble_contract.bonus_payout = 3000
	active_contracts.append(noble_contract)

	return active_contracts

## Fulfills a client contract using an eligible monster, adding payout to player gold.
func fulfill_contract(contract: ContractData, monster: MonsterInstance) -> Dictionary:
	if contract == null or monster == null:
		return {"success": false, "reason": "Invalid contract or monster", "payout": 0}

	# Verify License Gating for Noble contracts
	var license: LicenseService = _get_license_service()
	if contract.tier.to_lower() == "noble":
		if license != null and not license.can_access_contract("noble"):
			return {"success": false, "reason": "Noble contracts require Master License", "payout": 0}

	# Check beast eligibility
	if not contract.matches_beast(monster):
		return {"success": false, "reason": "Beast does not meet contract requirements", "payout": 0}

	var payout: int = contract.calculate_payout(monster)
	add_gold(payout)

	contract.is_fulfilled = true
	active_contracts.erase(contract)

	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("contract_fulfilled"):
		bus.contract_fulfilled.emit(contract.contract_id, monster.beast_id, payout)

	return {
		"success": true,
		"payout": payout,
		"contract_id": contract.contract_id,
		"client_name": contract.client_name
	}

## Liquidates an unwanted or reject beast from the clearance pen for 40% scrap gold value.
func liquidate_clearance_pen(beast: MonsterInstance) -> int:
	if beast == null:
		return 0

	var full_val: int = beast.calculate_appraisal_value()
	var scrap_gold: int = maxi(1, int(round(float(full_val) * 0.40)))

	add_gold(scrap_gold)
	clearance_pen.erase(beast)

	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("beast_liquidated"):
		bus.beast_liquidated.emit(beast.beast_id, scrap_gold)

	return scrap_gold

func _get_license_service() -> Node:
	if is_instance_valid(LicenseServiceScript.instance):
		return LicenseServiceScript.instance
	if is_inside_tree() and has_node("/root/LicenseService"):
		return get_node("/root/LicenseService")
	return null

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
