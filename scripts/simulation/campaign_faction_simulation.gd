class_name CampaignFactionSimulation
extends RefCounted
## Source-authored faction seeding, reputation cascades and autonomous agendas.
## The CampaignJournal remains the sole owner of mutable faction values.

const FACTION_RACES := {
	"silverhart_kingdom": "human",
	"ironbond_company": "human",
	"goblin_tribe": "goblin",
	"necromancer_cult": "undead",
	"orc_raiders": "orc",
	"dwarven_kingdom": "dwarf",
	"elven_realm": "elf",
	"thieves_guild": ""
}
const AGENDA_INTERVAL_SECONDS: float = 3600.0
const IRONBOND_STANDING_THRESHOLD: float = 10.0
const IRONBOND_INFLUENCE_DRIFT_PER_HOUR: float = 0.02
const GOBLIN_REPORTING_FRACTION: float = 0.35

var last_world_seconds: float = 0.0

static func _seed_standing(faction_race: String, player_race: String) -> float:
	if not faction_race.is_empty() and faction_race == player_race:
		return 5.0
	if player_race == "goblin" or player_race == "orc":
		if faction_race == "goblin" or faction_race == "orc":
			return 15.0
		if faction_race == "human" or faction_race == "elf" or faction_race == "dwarf":
			return -15.0
	return 0.0


static func seed_faction_standings(journal: CampaignJournal, player_race: String) -> void:
	if journal == null:
		return
	var normalized_race := player_race.strip_edges().to_lower()
	for faction_id_value in FACTION_RACES:
		var faction_id := String(faction_id_value)
		var faction_race := String(FACTION_RACES[faction_id])
		journal.seed_faction_reputation(faction_id, _seed_standing(faction_race, normalized_race), 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)


static func adjust_goblin_reputation(journal: CampaignJournal, standing_delta: float, knowledge_delta: float, reason: String = "") -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var result := journal.adjust_faction_reputation("goblin_tribe", standing_delta, knowledge_delta, reason)
	if not bool(result.get("ok", false)):
		return result
	# Hex-crpg's Skarn-tooth scouts report 35% of every reputation/knowledge
	# change to the wider orc raiders. This is intentionally one-way.
	result["cascade"] = journal.adjust_faction_reputation(
		"orc_raiders",
		standing_delta * GOBLIN_REPORTING_FRACTION,
		knowledge_delta * GOBLIN_REPORTING_FRACTION,
		reason + " (reported from the Skarn-tooth tribe)"
	)
	return result


func reset_world_time(world_seconds: float) -> void:
	last_world_seconds = maxf(0.0, world_seconds)


func advance_to(journal: CampaignJournal, world_seconds: float) -> void:
	if journal == null:
		return
	var current_world_seconds := maxf(0.0, world_seconds)
	var delta_seconds := maxf(0.0, current_world_seconds - last_world_seconds)
	last_world_seconds = current_world_seconds
	if delta_seconds <= 0.0:
		return
	var standing := journal.faction_standing("ironbond_company")
	var drift_per_hour := 0.0
	if standing > IRONBOND_STANDING_THRESHOLD:
		drift_per_hour = IRONBOND_INFLUENCE_DRIFT_PER_HOUR
	elif standing < -IRONBOND_STANDING_THRESHOLD:
		drift_per_hour = -IRONBOND_INFLUENCE_DRIFT_PER_HOUR
	if is_zero_approx(drift_per_hour):
		return
	var influence: Dictionary = journal.merchant_influence.get("ironbond_company", {}).duplicate(true)
	var drift := drift_per_hour * delta_seconds / 3600.0
	for kingdom_id_value in influence.keys():
		var kingdom_id := String(kingdom_id_value)
		var current := float(influence.get(kingdom_id, 0.0))
		influence[kingdom_id] = clampf(current + drift, 0.0, 100.0)
	journal.merchant_influence["ironbond_company"] = influence


func to_dict() -> Dictionary:
	return {"version": 1, "elapsed_agenda_seconds": elapsed_agenda_seconds}


func from_dict(data: Dictionary) -> void:
	elapsed_agenda_seconds = clampf(
		float(data.get("elapsed_agenda_seconds", 0.0)),
		0.0,
		AGENDA_INTERVAL_SECONDS - 0.000001
	)
