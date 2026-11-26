class_name PersistentCharacterRelationshipState
extends RefCounted
## Deeper, persistent relationships for important non-companion NPCs.
## Broad approval remains synchronised with CampaignJournal's -100..100 NPC
## standing; familiarity, trust and friendship are independent saved dimensions.
## Romance/attraction are only enabled for explicitly authored full profiles.

const HISTORY_LIMIT := 40
const KEY_LIMIT := 120
const AXES: Array[String] = ["approval", "familiarity", "trust", "friendship", "romantic_bond", "attraction"]

const PROFILES := {
	"seraphine_corrin": {"name":"Queen Seraphine Corrin","title":"Queen of the Silverhart Kingdom","race":"human","gender":"female","home":"Silverhart","faction_id":"silverhart_kingdom","role":"sovereign","affinity_mode":"full","familiarity_start":5,"trust_start":10,"friendship_start":0},
	"aelwen_silthandriel": {"name":"Queen Aelwen Sil'thandriel","title":"Queen of the Silver Leaf","race":"elf","gender":"female","home":"Sil'thandriel","faction_id":"elven_realm","role":"sovereign","affinity_mode":"friendship","familiarity_start":2,"trust_start":5,"friendship_start":0},
	"balrik_deepholm": {"name":"King Balrik Deepholm","title":"King Under the Mountain","race":"dwarf","gender":"male","home":"Kragmoor","faction_id":"dwarven_kingdom","role":"sovereign","affinity_mode":"friendship","familiarity_start":2,"trust_start":5,"friendship_start":0},
	"court_wizard_thessaly": {"name":"Court Wizard Thessaly","title":"The Queen's Court Wizard","race":"elf","gender":"female","home":"Silverhart","faction_id":"silverhart_kingdom","role":"court_wizard","affinity_mode":"friendship","familiarity_start":4,"trust_start":6,"friendship_start":0},
	"nessa_wren": {"name":"Elder Nessa Wren","title":"Warden of the Emberwood Grove","race":"elf","gender":"female","home":"Emberwood Grove","faction_id":"","role":"druid_elder","affinity_mode":"friendship","familiarity_start":4,"trust_start":7,"friendship_start":2},
	"petra_voss": {"name":"Guildmaster Petra Voss","title":"Ironbond Factor","race":"human","gender":"female","home":"Reddale","faction_id":"ironbond_company","role":"merchant_factor","affinity_mode":"friendship","familiarity_start":4,"trust_start":4,"friendship_start":0},
	"adelram": {"name":"High Cleric Adelram","title":"High Cleric of the Grand Cathedral","race":"human","gender":"male","home":"Silverhart","faction_id":"silverhart_kingdom","role":"high_cleric","affinity_mode":"friendship","familiarity_start":3,"trust_start":7,"friendship_start":0},
	"thrain_emberhand": {"name":"Thrain Emberhand","title":"Master Runesmith","race":"dwarf","gender":"male","home":"Kragmoor","faction_id":"dwarven_kingdom","role":"master_runesmith","affinity_mode":"friendship","familiarity_start":3,"trust_start":6,"friendship_start":1},
	"ilsa_rennick": {"name":"Captain Ilsa Rennick","title":"Captain of the Watch","race":"human","gender":"female","home":"Reddale","faction_id":"silverhart_kingdom","role":"watch_captain","affinity_mode":"friendship","familiarity_start":4,"trust_start":8,"friendship_start":1},
	"chief_skarnub": {"name":"Chief Skarnub","title":"Chief of the Skarn-tooth Tribe","race":"goblin","gender":"male","home":"Skarn-tooth Camp","faction_id":"goblin_tribe","role":"goblin_chief","affinity_mode":"friendship","familiarity_start":0,"trust_start":0,"friendship_start":0},
	"rowan_fletcher": {"name":"Rowan Fletcher","title":"Wandering hunter","race":"human","gender":"male","home":"Hollowmere hinterland","faction_id":"","role":"wandering_hunter","affinity_mode":"full","familiarity_start":0,"trust_start":5,"friendship_start":0}
}

var states: Dictionary = {}


static func roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for character_id in PROFILES:
		var profile: Dictionary = PROFILES[character_id]
		var entry := profile.duplicate(true)
		entry["id"] = character_id
		result.append(entry)
	return result


static func profile_for(character_id: String) -> Dictionary:
	return PROFILES.get(character_id, {}).duplicate(true)


func ensure(character_id: String, npc_standing: Variant = null) -> Dictionary:
	var profile: Dictionary = PROFILES.get(character_id, {})
	if profile.is_empty():
		return {}
	if not states.has(character_id):
		states[character_id] = {
			"approval": null,
			"pending_approval": false,
			"familiarity": int(profile.get("familiarity_start", 0)),
			"trust": int(profile.get("trust_start", 0)),
			"friendship": int(profile.get("friendship_start", 0)),
			"romantic_bond": 0,
			"attraction": 0,
			"known_conversation_keys": [],
			"known_event_keys": [],
			"history": []
		}
	var state: Dictionary = states[character_id]
	_normalise_state(state, profile)
	if npc_standing != null and not bool(state.get("pending_approval", false)):
		state["approval"] = _standing_to_approval(float(npc_standing))
	states[character_id] = state
	return state


func snapshot(character_id: String, npc_standing: Variant = null) -> Dictionary:
	var state := ensure(character_id, npc_standing)
	if state.is_empty():
		return {}
	var profile: Dictionary = PROFILES[character_id]
	return {
		"id": character_id,
		"name": String(profile["name"]),
		"affinity_mode": String(profile["affinity_mode"]),
		"approval": int(state["approval"]) if state["approval"] != null else 50,
		"familiarity": int(state["familiarity"]),
		"trust": int(state["trust"]),
		"friendship": int(state["friendship"]),
		"romantic_bond": int(state["romantic_bond"]),
		"attraction": int(state["attraction"])
	}


func set_relationship(character_id: String, patch: Dictionary, reason: String = "authored persistent-character change", npc_standing_available: bool = false) -> Dictionary:
	var state := ensure(character_id)
	if state.is_empty():
		return {}
	var profile: Dictionary = PROFILES[character_id]
	var before := snapshot(character_id)
	for axis_value in AXES:
		var axis := String(axis_value)
		if not patch.has(axis):
			continue
		if axis in ["romantic_bond", "attraction"] and String(profile["affinity_mode"]) != "full":
			continue
		var value := _clamp_axis(float(patch[axis]))
		if axis == "approval":
			state["approval"] = value
			state["pending_approval"] = not npc_standing_available
		else:
			state[axis] = value
	states[character_id] = state
	var after := snapshot(character_id)
	if not reason.is_empty() and before != after:
		_append_history(state, {"reason":reason,"state":after.duplicate(true)})
	states[character_id] = state
	return after


func adjust_relationship(character_id: String, delta: Dictionary, reason: String = "authored persistent-character change", npc_standing_available: bool = false) -> Dictionary:
	var current := snapshot(character_id)
	if current.is_empty():
		return {}
	var patch: Dictionary = {}
	for axis_value in AXES:
		var axis := String(axis_value)
		if delta.has(axis):
			patch[axis] = float(current[axis]) + float(delta[axis])
	return set_relationship(character_id, patch, reason, npc_standing_available)


func note_conversation(character_id: String, conversation_key: String, delta: Dictionary = {"familiarity":1}) -> Dictionary:
	return _record_keyed_change(character_id, conversation_key, delta, "conversation")


func record_event(character_id: String, event_key: String, delta: Dictionary = {}) -> Dictionary:
	return _record_keyed_change(character_id, event_key, delta, "event")


func has_recorded_event(character_id: String, event_key: String) -> bool:
	var state := ensure(character_id)
	if state.is_empty():
		return false
	return event_key in state.get("known_event_keys", [])


func is_persistent_character(character_id: String) -> bool:
	return PROFILES.has(character_id)


func standing_to_approval(standing: float) -> int:
	return _standing_to_approval(standing)


func approval_to_standing(approval: float) -> int:
	return int(clampi(_clamp_axis(approval) * 2 - 100, -100, 100))


func pending_npc_standing_sync(character_id: String) -> Dictionary:
	var state := ensure(character_id)
	if state.is_empty() or not bool(state.get("pending_approval", false)) or state.get("approval") == null:
		return {"pending":false}
	return {"pending":true,"standing":approval_to_standing(float(state["approval"]))}


func confirm_npc_standing_sync(character_id: String) -> bool:
	var state := ensure(character_id)
	if state.is_empty() or not bool(state.get("pending_approval", false)):
		return false
	state["pending_approval"] = false
	states[character_id] = state
	return true


func sync_with_journal(character_id: String, journal: CampaignJournal) -> Dictionary:
	if journal == null or not PROFILES.has(character_id):
		return {"ok":false,"reason":"missing_journal_or_unknown_character"}
	ensure(character_id, journal.npc_standing(character_id))
	var pending := pending_npc_standing_sync(character_id)
	if bool(pending.get("pending", false)):
		var target_standing := int(pending.get("standing", 0))
		var current_standing := journal.npc_standing(character_id)
		var delta := target_standing - roundi(current_standing)
		if delta != 0:
			var changed := journal.adjust_npc_standing(character_id, delta, "persistent character approval synchronised")
			if not bool(changed.get("ok", false)):
				return changed
		confirm_npc_standing_sync(character_id)
	return {"ok":true,"relationship":snapshot(character_id, journal.npc_standing(character_id))}


func sync_all_with_journal(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_journal"}
	var relationships: Dictionary = {}
	for character_id in PROFILES:
		var result := sync_with_journal(String(character_id), journal)
		if not bool(result.get("ok", false)):
			return result
		relationships[String(character_id)] = result.get("relationship", {})
	return {"ok":true,"relationships":relationships}


func to_dict() -> Dictionary:
	return {"version":1,"states":states.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	var incoming: Variant = data.get("states", {})
	states = incoming.duplicate(true) if incoming is Dictionary else {}
	for character_id in states.keys():
		if not PROFILES.has(String(character_id)) or not (states[character_id] is Dictionary):
			states.erase(character_id)
			continue
		_normalise_state(states[character_id], PROFILES[character_id])


func _record_keyed_change(character_id: String, key: String, delta: Dictionary, prefix: String) -> Dictionary:
	var state := ensure(character_id)
	if state.is_empty():
		return {}
	if key.strip_edges().is_empty():
		return snapshot(character_id)
	var list_key := "known_conversation_keys" if prefix == "conversation" else "known_event_keys"
	var keys: Array = state.get(list_key, [])
	if keys.has(key):
		return snapshot(character_id)
	keys.append(key)
	if keys.size() > KEY_LIMIT:
		keys = keys.slice(keys.size() - KEY_LIMIT)
	state[list_key] = keys
	states[character_id] = state
	return adjust_relationship(character_id, delta, prefix + ":" + key)


func _normalise_state(state: Dictionary, profile: Dictionary) -> void:
	for axis_value in AXES:
		var axis := String(axis_value)
		if axis == "approval" and state.get(axis) == null:
			continue
		var fallback := 0
		match axis:
			"familiarity": fallback = int(profile.get("familiarity_start", 0))
			"trust": fallback = int(profile.get("trust_start", 0))
			"friendship": fallback = int(profile.get("friendship_start", 0))
		if axis in ["romantic_bond", "attraction"] and String(profile.get("affinity_mode", "friendship")) != "full":
			state[axis] = 0
		else:
			state[axis] = _clamp_axis(float(state.get(axis, fallback)))
	if not state.has("pending_approval"):
		state["pending_approval"] = false
	for key in ["known_conversation_keys", "known_event_keys", "history"]:
		if not (state.get(key) is Array):
			state[key] = []
	state["history"] = state["history"].slice(maxi(0, state["history"].size() - HISTORY_LIMIT))


func _append_history(state: Dictionary, entry: Dictionary) -> void:
	var history: Array = state.get("history", [])
	history.append(entry)
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT)
	state["history"] = history



func _standing_to_approval(standing: float) -> int:
	return _clamp_axis((standing + 100.0) / 2.0)


func _clamp_axis(value: float) -> int:
	return int(clampi(roundi(value), 0, 100))
