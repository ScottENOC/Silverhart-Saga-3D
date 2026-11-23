class_name CompanionRelationshipState
extends RefCounted
## Source-faithful persistent companion relationship state.
## Approval, familiarity, trust, friendship, romantic bond and attraction are
## independent dimensions. Relationship/sexual agreements are explicit state,
## never inferred from a meter. This class is deliberately presentation-agnostic.

const VOICE_LINES := {
	"wren_talbot": {"love_desire_conflict": "I know what I feel for you. Knowing what to do with it is the difficult part.", "close_friend": "You’re stuck with me. Friendship has its hazards.", "romantic": "I’m here because I choose you. Don’t make me regret saying that out loud."},
	"ser_aldric_thorne": {"restrained_attraction": "Finding someone attractive is not the same thing as making them a promise. I try not to confuse the two.", "close_friend": "I trust you at my back. That is not a small thing to me.", "romantic": "If I give you my heart, I mean to do it honestly and without keeping another in reserve."},
	"fenn_oakheart": {"casual_hookup": "We can enjoy a night without asking it to become a lifetime.", "friends_with_benefits": "We’re friends, we want each other, and nobody needs to pretend that makes the friendship less real.", "romantic": "Love doesn’t become smaller because it isn’t fenced in.", "close_friend": "You’re easy company. I mean that as a much bigger compliment than it sounds."},
	"reyna_fletcher": {"casual_hookup": "One night doesn’t have to become a ballad. Sometimes it can just be a very good night.", "friends_with_benefits": "We’re friends. We fancy each other. I don’t see why either fact needs to make the other complicated.", "romantic": "I’m serious about you. Serious doesn’t mean I own you.", "close_friend": "You’re one of the few people I’d choose beside me when the arrows start flying."},
	"mirabel_quill": {"casual_hookup": "Desire is simple. It’s all the things people decide it has to mean afterwards that get tedious.", "friends_with_benefits": "I can stay for this without promising forever. Apparently I’m learning.", "romantic": "I always thought leaving was the easy part. You’ve made staying considerably more dangerous.", "close_friend": "I keep telling myself I travel light. You’re becoming inconvenient evidence to the contrary."},
	"brother_alden": {"asexual_romance": "I don’t desire you sexually. I do choose you. Neither statement makes the other less true.", "close_friend": "Peace is easier around some people. I’ve noticed it is easier around you.", "romantic": "What I want is closeness, constancy, and a life shared honestly. I have never needed desire to know love."}
}

const AXES: Array[String] = [
	"approval",
	"familiarity",
	"trust",
	"friendship",
	"romantic_bond",
	"attraction"
]

const PROFILES := {
	"wren_talbot": {
		"name": "Wren Talbot",
		"orientation_label": "straight",
		"affinity_mode": "full",
		"strong_physical_desire_threshold": 60,
		"familiarity_start": 35,
		"trust_start": 25,
		"approval_start": 50,
		"friendship_start": 38,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.18,
		"attraction_caps": {"masculine": 100, "feminine": 30, "androgynous": 45, "unknown": 35},
		"romantic_caps": {"masculine": 100, "feminine": 85, "androgynous": 90, "unknown": 75},
		"relationship_style": {"romantic_exclusivity": "exclusive", "sexual_exclusivity": "exclusive", "casual_sex": false, "friends_with_benefits": false, "group_relationships": false, "breach_response": "wren"}
	},
	"ser_aldric_thorne": {
		"name": "Ser Aldric Thorne",
		"orientation_label": "straight",
		"affinity_mode": "full",
		"strong_physical_desire_threshold": 60,
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 18,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.10,
		"attraction_caps": {"masculine": 5, "feminine": 100, "androgynous": 20, "unknown": 20},
		"romantic_caps": {"masculine": 10, "feminine": 100, "androgynous": 30, "unknown": 25},
		"relationship_style": {"romantic_exclusivity": "exclusive", "sexual_exclusivity": "exclusive", "casual_sex": false, "friends_with_benefits": false, "group_relationships": false, "breach_response": "aldric", "can_reconcile_once": true}
	},
	"fenn_oakheart": {
		"name": "Fenn Oakheart",
		"orientation_label": "bisexual",
		"affinity_mode": "full",
		"strong_physical_desire_threshold": 60,
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 16,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.12,
		"attraction_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 90},
		"romantic_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 95},
		"relationship_style": {"romantic_exclusivity": "open", "sexual_exclusivity": "open", "casual_sex": true, "friends_with_benefits": true, "group_relationships": true, "breach_response": "cnm"}
	},
	"reyna_fletcher": {
		"name": "Reyna Fletcher",
		"orientation_label": "lesbian",
		"affinity_mode": "full",
		"strong_physical_desire_threshold": 60,
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 16,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.12,
		"attraction_caps": {"masculine": 5, "feminine": 100, "androgynous": 75, "unknown": 50},
		"romantic_caps": {"masculine": 10, "feminine": 100, "androgynous": 85, "unknown": 60},
		"relationship_style": {"romantic_exclusivity": "open", "sexual_exclusivity": "open", "casual_sex": true, "friends_with_benefits": true, "group_relationships": true, "breach_response": "cnm"}
	},
	"mirabel_quill": {
		"name": "Mirabel Quill",
		"orientation_label": "bisexual",
		"affinity_mode": "full",
		"strong_physical_desire_threshold": 60,
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 12,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.12,
		"attraction_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 90},
		"romantic_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 95},
		"relationship_style": {"romantic_exclusivity": "open", "sexual_exclusivity": "open", "casual_sex": true, "friends_with_benefits": true, "group_relationships": true, "breach_response": "cnm"}
	},
	"brother_alden": {
		"name": "Brother Alden",
		"orientation_label": "asexual, biromantic",
		"affinity_mode": "full",
		"strong_physical_desire_threshold": 101,
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 18,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.0,
		"attraction_caps": {"masculine": 0, "feminine": 0, "androgynous": 0, "unknown": 0},
		"romantic_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 100},
		"relationship_style": {"romantic_exclusivity": "exclusive", "sexual_exclusivity": "open", "casual_sex": false, "friends_with_benefits": false, "group_relationships": false, "seeks_sex": false, "breach_response": "alden"}
	}
}

const WREN_STORY_EVENTS := {
	"hollowmere_shakedown:fight": {"friendship": 3, "attraction": 2, "reason": "stood up for Hollowmere under pressure"},
	"hollowmere_shakedown:stay_out": {"friendship": -2, "attraction": -1, "reason": "stood aside while Hollowmere was threatened"},
	"hollowmere_shakedown:encourage_pay": {"friendship": -4, "romantic_bond": -2, "attraction": -2, "reason": "backed Ironbond coercion against Wren’s home"},
	"goblin_favour:scout": {"friendship": -6, "romantic_bond": -3, "attraction": -2, "reason": "scouted Wren’s home for raiders"},
	"goblin_favour:steal": {"friendship": -4, "romantic_bond": -2, "attraction": -1, "reason": "stole from Wren’s community for raiders"},
	"goblin_favour:raid_mine": {"friendship": -5, "romantic_bond": -3, "attraction": -2, "reason": "raided civilians for plunder"},
	"goblin_resolution:assault": {"friendship": 3, "attraction": 2, "reason": "protected Hollowmere decisively"},
	"goblin_resolution:stealth_succession": {"friendship": 4, "attraction": 3, "reason": "protected Hollowmere with nerve and restraint"},
	"goblin_resolution:goblin_diplomacy": {"friendship": 4, "attraction": 1, "reason": "protected Hollowmere without needless bloodshed"},
	"goblin_resolution:goblin_alliance": {"friendship": -3, "romantic_bond": -1, "reason": "accepted continuing danger to Wren’s home"},
	"goblin_resolution:betrayal": {"friendship": -18, "romantic_bond": -14, "attraction": -12, "reason": "betrayed Wren and Hollowmere"},
	"parents_search_promise": {"friendship": 2, "romantic_bond": 1, "reason": "offered to help with Wren’s missing parents"},
	"parents_search_reached_millbrook": {"friendship": 6, "romantic_bond": 4, "reason": "remembered and kept a deeply personal promise"},
	"parents_investigation:support": {"friendship": 8, "romantic_bond": 6, "reason": "stood beside Wren without taking her grief away from her"},
	"parents_investigation:restore_names": {"friendship": 7, "romantic_bond": 5, "reason": "helped restore Wren’s parents’ names"},
	"parents_investigation:closure": {"friendship": 6, "romantic_bond": 4, "reason": "helped Wren find closure"},
	"player_became_lich": {"friendship": -22, "romantic_bond": -18, "attraction": -30, "reason": "chose lichdom despite its cost to the people beside them"}
}

const WREN_DISPOSITION_EVENTS := {
	"hollowmere_shakedown:fight": {"approval": 10, "trust": 8, "reason": "stood with Hollowmere against the Ironbond shakedown"},
	"hollowmere_shakedown:stay_out": {"approval": -4, "trust": -3, "reason": "stood aside while Ironbond threatened the Hollow Tankard"},
	"hollowmere_shakedown:encourage_pay": {"approval": -10, "trust": -6, "reason": "backed Ironbond while they extorted Garrick"},
	"goblin_favour:scout": {"approval": -12, "trust": -12, "reason": "gave Hollowmere scouting information to the goblins"},
	"goblin_favour:steal": {"approval": -8, "trust": -6, "reason": "stole from Hollowmere folk for the goblins"},
	"goblin_favour:raid_mine": {"approval": -15, "trust": -12, "reason": "helped the goblins raid Emberlode for plunder"},
	"goblin_resolution:assault": {"approval": 10, "trust": 8, "reason": "broke the Skarn-tooth threat to Hollowmere"},
	"goblin_resolution:stealth_succession": {"approval": 12, "trust": 8, "reason": "ended the Skarn-tooth threat without a massacre"},
	"goblin_resolution:goblin_diplomacy": {"approval": 8, "trust": 6, "reason": "got the Skarn-tooth tribe away from Hollowmere peacefully"},
	"goblin_resolution:goblin_alliance": {"approval": -10, "trust": -8, "reason": "let a raiding tribe settle permanently on Hollowmere’s doorstep"},
	"goblin_resolution:betrayal": {"approval": -40, "trust": -35, "reason": "betrayed Wren and Hollowmere"},
	"parents_search_promise": {"approval": 2, "trust": 1, "reason": "promised to help look for Wren’s parents in Millbrook"},
	"parents_search_reached_millbrook": {"approval": 5, "trust": 10, "reason": "kept the promise to bring Wren to Millbrook and ask about her parents"},
	"player_became_lich": {"approval": -50, "trust": -100, "reason": "chose lichdom and dragged Wren into its consequences"}
}

const WREN_DIALOGUE_EVENTS := {
	"people_do_not_give_up": {"friendship": 4, "romantic_bond": 2, "reason": "affirmed that people should not give up on each other"},
	"loyalty_has_limits": {"friendship": 5, "romantic_bond": 2, "reason": "invited Wren to challenge the player when they are wrong"},
	"look_after_our_own": {"friendship": 2, "romantic_bond": 1, "attraction": 1, "reason": "defined the pair as people who protect their own"},
	"you_do_not_owe_me": {"friendship": 7, "romantic_bond": 5, "reason": "made Wren’s loyalty a free choice rather than an obligation"},
	"truth_even_when_it_hurts": {"friendship": 4, "romantic_bond": 2, "reason": "valued truth even when it hurts"},
	"hurt_ours_no_second_chance": {"friendship": 1, "attraction": 1, "reason": "shared Wren’s protective anger"},
	"do_not_become_them": {"friendship": 5, "romantic_bond": 3, "reason": "urged Wren not to let cruelty define her"},
	"power_keeps_us_safe": {"friendship": 1, "attraction": 2, "reason": "made a forceful case for power as protection"}
}

var states: Dictionary = {}


func has_profile(companion_id: String) -> bool:
	return PROFILES.has(companion_id)


func profile_for(companion_id: String) -> Dictionary:
	var profile: Dictionary = PROFILES.get(companion_id, {})
	return profile.duplicate(true)


func ensure(companion_id: String, presentation: String = "masculine") -> Dictionary:
	if not PROFILES.has(companion_id):
		return {}
	if states.has(companion_id):
		var existing: Dictionary = states[companion_id]
		if existing.get("presentation", "") == "unknown" and presentation != "unknown":
			existing["presentation"] = _normalise_presentation(presentation)
			_apply_caps(companion_id, existing)
			states[companion_id] = existing
		return existing
	var profile: Dictionary = PROFILES[companion_id]
	var normalized_presentation := _normalise_presentation(presentation)
	var attraction_caps: Dictionary = profile["attraction_caps"]
	var attraction_cap := float(attraction_caps.get(normalized_presentation, attraction_caps.get("unknown", 0)))
	var state := {
		"companion_id": companion_id,
		"presentation": normalized_presentation,
		"approval": float(profile["approval_start"]),
		"familiarity": float(profile["familiarity_start"]),
		"trust": float(profile["trust_start"]),
		"friendship": float(profile["friendship_start"]),
		"romantic_bond": float(profile["romantic_bond_start"]),
		"attraction": float(roundi(attraction_cap * float(profile["initial_attraction_fraction"]))),
		"romance_state": "unspoken",
		"agreement": {
			"state": "none",
			"romantic_exclusivity": String(profile["relationship_style"].get("romantic_exclusivity", "unspoken")),
			"sexual_exclusivity": String(profile["relationship_style"].get("sexual_exclusivity", "unspoken")),
			"group_relationships": bool(profile["relationship_style"].get("group_relationships", false)),
			"established_world_seconds": 0.0,
			"breaches": [],
			"reconciliation_used": false
		},
		"known_conversation_keys": [],
		"known_event_keys": [],
		"known_trust_event_keys": [],
		"last_shared_party_day": null,
		"history": []
	}
	_apply_caps(companion_id, state)
	states[companion_id] = state
	return state


func snapshot(companion_id: String) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {}
	var result := state.duplicate(true)
	result.erase("known_conversation_keys")
	result.erase("known_event_keys")
	result.erase("known_trust_event_keys")
	result.erase("history")
	return result


func set_presentation(companion_id: String, presentation: String) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	state["presentation"] = _normalise_presentation(presentation)
	_apply_caps(companion_id, state)
	states[companion_id] = state
	return {"ok": true, "state": snapshot(companion_id)}


func adjust(companion_id: String, changes: Dictionary, reason: String = "") -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var before := snapshot(companion_id)
	for axis_value in changes.keys():
		var axis := String(axis_value)
		if not AXES.has(axis):
			continue
		if axis == "romantic_bond" or axis == "attraction":
			if String(PROFILES[companion_id]["affinity_mode"]) != "full":
				continue
		state[axis] = float(clampi(roundi(float(state.get(axis, 0.0)) + float(changes[axis_value])), 0, 100))
	_apply_caps(companion_id, state)
	states[companion_id] = state
	var after := snapshot(companion_id)
	if not reason.is_empty() and before != after:
		_append_history(state, {"reason": reason, "state": after})
		states[companion_id] = state
	return {"ok": true, "state": after}


func apply_wren_authored_event(event_key: String) -> Dictionary:
	var story_event: Dictionary = WREN_STORY_EVENTS.get(event_key, {})
	var disposition_event: Dictionary = WREN_DISPOSITION_EVENTS.get(event_key, {})
	var dialogue_event: Dictionary = WREN_DIALOGUE_EVENTS.get(event_key, {})
	if story_event.is_empty() and disposition_event.is_empty() and dialogue_event.is_empty():
		return {"ok": false, "reason": "unknown_wren_event"}
	var changes: Dictionary = {}
	var reason := ""
	for event_value in [story_event, disposition_event, dialogue_event]:
		var event: Dictionary = event_value
		for axis_value in event.keys():
			var axis := String(axis_value)
			if AXES.has(axis):
				changes[axis] = float(changes.get(axis, 0.0)) + float(event[axis_value])
		if reason.is_empty() and event.has("reason"):
			reason = String(event["reason"])
	return record_event("wren_talbot", event_key, changes, reason)


func note_conversation(companion_id: String, conversation_key: String, familiarity_gain: float = 2.0) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if conversation_key.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_conversation_key"}
	var keys: Array = state["known_conversation_keys"]
	if keys.has(conversation_key):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	keys.append(conversation_key)
	if keys.size() > 80:
		keys = keys.slice(keys.size() - 80)
	state["known_conversation_keys"] = keys
	states[companion_id] = state
	var result := adjust(companion_id, {"familiarity": maxf(0.0, familiarity_gain)}, "conversation:" + conversation_key)
	result["changed"] = true
	return result


func record_event(companion_id: String, event_key: String, changes: Dictionary, reason: String = "") -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if event_key.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_event_key"}
	var keys: Array = state["known_event_keys"]
	if keys.has(event_key):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	keys.append(event_key)
	if keys.size() > 100:
		keys = keys.slice(keys.size() - 100)
	state["known_event_keys"] = keys
	states[companion_id] = state
	var result := adjust(companion_id, changes, reason if not reason.is_empty() else "event:" + event_key)
	result["changed"] = true
	return result


func record_trust_event(companion_id: String, event_key: String, trust_delta: float, reason: String = "") -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if event_key.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_event_key"}
	var keys: Array = state["known_trust_event_keys"]
	if keys.has(event_key):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	keys.append(event_key)
	if keys.size() > 80:
		keys = keys.slice(keys.size() - 80)
	state["known_trust_event_keys"] = keys
	states[companion_id] = state
	var result := adjust(companion_id, {"trust": trust_delta}, reason if not reason.is_empty() else "trust:" + event_key)
	result["changed"] = true
	return result


func set_agreement(companion_id: String, updates: Dictionary, world_seconds: float = 0.0) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var agreement: Dictionary = state["agreement"]
	for key in ["state", "romantic_exclusivity", "sexual_exclusivity", "group_relationships", "reconciliation_used"]:
		if updates.has(key):
			agreement[key] = updates[key]
	if updates.has("breaches") and updates["breaches"] is Array:
		agreement["breaches"] = updates["breaches"].duplicate(true)
	if String(agreement.get("state", "none")) != "none" and float(agreement.get("established_world_seconds", 0.0)) <= 0.0:
		agreement["established_world_seconds"] = world_seconds
	state["agreement"] = agreement
	if updates.has("state"):
		state["romance_state"] = String(updates["state"])
	states[companion_id] = state
	return {"ok": true, "agreement": agreement.duplicate(true)}


func note_personal_dialogue(companion_id: String, dialogue_key: String) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if float(state.get("familiarity", 0.0)) >= 60.0:
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	return note_conversation(companion_id, "personal_dialogue:" + dialogue_key, minf(2.0, 60.0 - float(state.get("familiarity", 0.0))))


func tick_shared_familiarity(companion_id: String, day_index: int) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var previous_day: Variant = state.get("last_shared_party_day", null)
	if previous_day == null:
		state["last_shared_party_day"] = day_index
		states[companion_id] = state
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	if day_index <= int(previous_day):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	var elapsed_days := day_index - int(previous_day)
	state["last_shared_party_day"] = day_index
	states[companion_id] = state
	var current_familiarity := float(state.get("familiarity", 0.0))
	if current_familiarity >= 50.0:
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	var gain := minf(float(elapsed_days), 50.0 - current_familiarity)
	return adjust(companion_id, {"familiarity": gain}, "shared_time:" + str(day_index))

func commit_relationship(companion_id: String, relationship_state: String = "committed", world_seconds: float = 0.0) -> Dictionary:
	var profile: Dictionary = PROFILES.get(companion_id, {})
	if profile.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var style: Dictionary = profile.get("relationship_style", {})
	return set_agreement(companion_id, {
		"state": relationship_state,
		"romantic_exclusivity": style.get("romantic_exclusivity", "unspoken"),
		"sexual_exclusivity": style.get("sexual_exclusivity", "unspoken"),
		"group_relationships": bool(style.get("group_relationships", false))
	}, world_seconds)


func record_outside_connection(companion_id: String, other_name: String, connection_kind: String, disclosed: bool = true, world_seconds: float = 0.0, wren_security: float = 0.0) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var agreement: Dictionary = state.get("agreement", {})
	var active := ["dating", "committed", "strained"].has(String(agreement.get("state", "none")))
	var romantic_violation := active and connection_kind == "romance" and String(agreement.get("romantic_exclusivity", "unspoken")) == "exclusive"
	var sexual_violation := active and connection_kind == "sex" and String(agreement.get("sexual_exclusivity", "unspoken")) == "exclusive"
	var cnm_deception := active and not disclosed and (String(agreement.get("romantic_exclusivity", "")) == "open" or String(agreement.get("sexual_exclusivity", "")) == "open")
	var breach := romantic_violation or sexual_violation or cnm_deception
	var event := {
		"other_name": other_name if not other_name.is_empty() else "someone else",
		"kind": connection_kind if not connection_kind.is_empty() else "unknown",
		"disclosed": disclosed,
		"breach": breach,
		"world_seconds": world_seconds
	}
	if not breach:
		return {"ok": true, "allowed": true, "breach": false, "agreement": agreement.duplicate(true), "event": event}
	var breaches: Array = agreement.get("breaches", [])
	breaches.append(event)
	agreement["breaches"] = breaches
	var reason := ""
	if cnm_deception:
		reason = "hid another " + connection_kind + " connection from " + String(PROFILES[companion_id]["name"])
	else:
		var connection_label := "sexual" if connection_kind == "sex" else "romantic"
		reason = "broke " + String(PROFILES[companion_id]["name"]) + "’s " + connection_label + " exclusivity agreement"
	var response := String(PROFILES[companion_id]["relationship_style"].get("breach_response", "cnm"))
	var changes: Dictionary = {}
	match response:
		"cnm":
			agreement["state"] = "strained"
			changes = {"friendship": -6.0, "romantic_bond": -3.0, "trust": -8.0}
		"aldric":
			agreement["state"] = "ended"
			state["romance_state"] = "ended_breach"
			changes = {"friendship": -10.0, "romantic_bond": -15.0, "trust": -20.0}
		"alden":
			agreement["state"] = "ended"
			state["romance_state"] = "ended_breach"
			changes = {"friendship": -8.0, "romantic_bond": -12.0, "trust": -18.0}
		"wren":
			if wren_security >= 35.0:
				agreement["state"] = "ended"
				state["romance_state"] = "ended_breach"
				changes = {"friendship": -10.0, "romantic_bond": -10.0, "trust": -22.0}
			else:
				agreement["state"] = "strained"
				state["romance_state"] = "strained_breach"
				changes = {"friendship": -10.0, "romantic_bond": -8.0, "trust": -25.0}
	agreement["breaches"] = breaches
	state["agreement"] = agreement
	states[companion_id] = state
	var applied := adjust(companion_id, changes, reason)
	return {"ok": true, "allowed": false, "breach": true, "agreement": agreement.duplicate(true), "event": event, "state": applied.get("state", {})}


func interpret_relationship(companion_id: String) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {}
	var profile: Dictionary = PROFILES[companion_id]
	var style: Dictionary = profile.get("relationship_style", {})
	var friendship := float(state.get("friendship", 0.0))
	var romantic_bond := float(state.get("romantic_bond", 0.0))
	var attraction := float(state.get("attraction", 0.0))
	var mode := "early"
	if companion_id == "brother_alden" and romantic_bond >= 55.0 and friendship >= 50.0:
		mode = "asexual_romance"
	elif companion_id == "wren_talbot" and String(state.get("presentation", "")) == "feminine" and romantic_bond >= 60.0 and attraction <= 30.0 and friendship >= 60.0:
		mode = "love_desire_conflict"
	elif companion_id == "ser_aldric_thorne" and attraction >= 50.0 and romantic_bond < 30.0:
		mode = "restrained_attraction"
	elif romantic_bond >= 60.0 and friendship >= 50.0:
		mode = "romantic"
	elif attraction >= 60.0 and romantic_bond < 25.0 and friendship < 45.0 and bool(style.get("casual_sex", false)):
		mode = "casual_hookup"
	elif attraction >= 50.0 and romantic_bond < 35.0 and friendship >= 55.0 and bool(style.get("friends_with_benefits", false)):
		mode = "friends_with_benefits"
	elif friendship >= 65.0 and romantic_bond < 40.0:
		mode = "close_friend"
	elif romantic_bond >= 35.0 and attraction <= 30.0:
		mode = "romantic_low_desire"
	elif attraction >= 40.0:
		mode = "attracted"
	var lines: Dictionary = VOICE_LINES.get(companion_id, {})
	return {
		"companion_id": companion_id,
		"mode": mode,
		"friendship": friendship,
		"romantic_bond": romantic_bond,
		"attraction": attraction,
		"trust": float(state.get("trust", 0.0)),
		"familiarity": float(state.get("familiarity", 0.0)),
		"relationship_style": style.duplicate(true),
		"strong_physical_desire_threshold": int(profile.get("strong_physical_desire_threshold", 60)),
		"line": String(lines.get(mode, ""))
	}


func get_relationship_state(companion_id: String) -> Dictionary:
	var state := snapshot(companion_id)
	if state.is_empty():
		return {}
	var agreement: Dictionary = state.get("agreement", {})
	return {
		"state": state,
		"agreement": agreement.duplicate(true),
		"interpretation": interpret_relationship(companion_id)
	}


func to_dict() -> Dictionary:
	return {"version": 1, "companions": states.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	states.clear()
	var saved: Variant = data.get("companions", {})
	if not saved is Dictionary:
		return
	for companion_id_value in saved.keys():
		var companion_id := String(companion_id_value)
		if not PROFILES.has(companion_id) or not saved[companion_id_value] is Dictionary:
			continue
		var state: Dictionary = saved[companion_id_value].duplicate(true)
		var defaults := ensure(companion_id, String(state.get("presentation", "unknown")))
		for key in defaults.keys():
			if not state.has(key):
				state[key] = defaults[key]
		_apply_caps(companion_id, state)
		states[companion_id] = state


func _apply_caps(companion_id: String, state: Dictionary) -> void:
	var profile: Dictionary = PROFILES[companion_id]
	var presentation := _normalise_presentation(String(state.get("presentation", "unknown")))
	var attraction_caps: Dictionary = profile["attraction_caps"]
	var romantic_caps: Dictionary = profile["romantic_caps"]
	state["attraction"] = float(clampi(roundi(float(state.get("attraction", 0.0))), 0, int(attraction_caps.get(presentation, attraction_caps.get("unknown", 0)))))
	state["romantic_bond"] = float(clampi(roundi(float(state.get("romantic_bond", 0.0))), 0, int(romantic_caps.get(presentation, romantic_caps.get("unknown", 0)))))


func _append_history(state: Dictionary, entry: Dictionary) -> void:
	var history: Array = state.get("history", [])
	history.append(entry)
	if history.size() > 40:
		history = history.slice(history.size() - 40)
	state["history"] = history


func _normalise_presentation(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if ["masculine", "feminine", "androgynous", "unknown"].has(normalized) else "unknown"
