class_name CampaignFactionSystem
extends RefCounted
## Source-backed faction seeding, reputation spillover and autonomous agendas.
## Mutable values remain owned by CampaignJournal so saves and quests share one state.

const FACTION_RACES := {
	"silverhart_kingdom":"human",
	"ironbond_company":"human",
	"goblin_tribe":"goblin",
	"necromancer_cult":"undead",
	"orc_raiders":"orc",
	"dwarven_kingdom":"dwarf",
	"elven_realm":"elf",
	"thieves_guild":""
}
const IRONBOND_INFLUENCE_KINGDOM := "silverhart_kingdom"
const IRONBOND_INITIAL_INFLUENCE := 30.0
const GOBLIN_HORDE_SPILLOVER := 0.35
const REPUTATION_CASCADE_FALLOFF := 0.4
const IRONBOND_AGENDA_DRIFT_PER_HOUR := 0.02


static func seed_standing(faction_race: String, player_race: String) -> float:
	var faction := faction_race.strip_edges().to_lower()
	var player := player_race.strip_edges().to_lower()
	if faction.is_empty() or player.is_empty():
		return 0.0
	if faction == player:
		return 5.0
	if player in ["goblin", "orc"]:
		if faction in ["goblin", "orc"]:
			return 15.0
		if faction in ["human", "elf", "dwarf"]:
			return -15.0
	return 0.0


static func initialize_social_standings(
	journal: CampaignJournal,
	player_race: String,
	world_seconds: float = -1.0
) -> void:
	if journal == null:
		return
	for faction_id_value in FACTION_RACES:
		var faction_id := String(faction_id_value)
		journal.seed_faction_reputation(
			faction_id,
			seed_standing(String(FACTION_RACES[faction_id]), player_race),
			0.0
		)
	journal.seed_merchant_influence("ironbond_company", IRONBOND_INFLUENCE_KINGDOM, IRONBOND_INITIAL_INFLUENCE)
	if world_seconds >= 0.0 and journal.faction_agenda_last_world_seconds < 0.0:
		journal.faction_agenda_last_world_seconds = world_seconds


static func adjust_reputation(
	journal: CampaignJournal,
	faction_id: String,
	standing_delta: float,
	knowledge_delta: float,
	reason: String = ""
) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_journal"}
	var primary := journal.adjust_faction_reputation(faction_id, standing_delta, knowledge_delta, reason)
	if not bool(primary.get("ok", false)):
		return primary
	var result := {
		"ok":true,
		"faction_id":faction_id,
		"primary":primary,
		"spillover":{}
	}
	if faction_id == "goblin_tribe":
		var spillover := journal.adjust_faction_reputation(
			"orc_raiders",
			standing_delta * GOBLIN_HORDE_SPILLOVER,
			knowledge_delta * GOBLIN_HORDE_SPILLOVER,
			reason + " (Skarn-tooth report)"
		)
		result["spillover"] = spillover
	return result


static func cascade_reputation(
	journal: CampaignJournal,
	faction_ids: Array[String],
	standing_delta: float,
	knowledge_delta: float,
	reason: String = "",
	falloff: float = REPUTATION_CASCADE_FALLOFF
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if journal == null:
		return results
	var safe_falloff := clampf(falloff, 0.0, 1.0)
	for index in range(faction_ids.size()):
		var multiplier := pow(safe_falloff, index)
		results.append(adjust_reputation(
			journal,
			faction_ids[index],
			standing_delta * multiplier,
			knowledge_delta * multiplier,
			reason
		))
	return results


static func advance_time(journal: CampaignJournal, elapsed_seconds: float) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_journal"}
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return {"ok":false,"reason":"invalid_elapsed_time"}
	if elapsed_seconds <= 0.0:
		return {"ok":true,"advanced_seconds":0.0,"drift":0.0}
	var standing := journal.faction_standing("ironbond_company")
	var drift_per_hour := 0.0
	if standing > 10.0:
		drift_per_hour = IRONBOND_AGENDA_DRIFT_PER_HOUR
	elif standing < -10.0:
		drift_per_hour = -IRONBOND_AGENDA_DRIFT_PER_HOUR
	var drift := drift_per_hour * elapsed_seconds / 3600.0
	if not is_zero_approx(drift):
		journal.adjust_merchant_influence(
			"ironbond_company",
			IRONBOND_INFLUENCE_KINGDOM,
			drift,
			"autonomous Ironbond commercial agenda"
		)
	return {"ok":true,"advanced_seconds":elapsed_seconds,"drift":drift}
