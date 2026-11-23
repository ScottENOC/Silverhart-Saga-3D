class_name WrenCharacterArcState
extends RefCounted
## Long-horizon development: player values and the person Wren becomes.
## Relationship axes remain owned by CompanionRelationshipState.

const META_KEY := "wren_character_arc_state"
const PLAYER_START := {"personalLoyalty": 0.0, "mercy": 0.0}
const WREN_START := {"personalLoyalty": 20.0, "mercy": 15.0, "security": -20.0}
const STORY_INFLUENCE := {
	"hollowmere_shakedown:fight": {"player": {"personalLoyalty": 3, "mercy": 1}, "wrenModel": {"personalLoyalty": 3, "mercy": 1}, "wrenImpact": {"security": 2}, "reason": "stood up for people Wren considers her own"},
	"hollowmere_shakedown:stay_out": {"player": {"personalLoyalty": -2}, "wrenModel": {"personalLoyalty": 1}, "wrenImpact": {"security": -2}, "reason": "stood aside while Wren's community was threatened"},
	"hollowmere_shakedown:encourage_pay": {"player": {"personalLoyalty": -3, "mercy": -3}, "wrenModel": {"mercy": -1}, "wrenImpact": {"security": -3}, "reason": "backed coercion against people Wren knows"},
	"goblin_favour:scout": {"player": {"personalLoyalty": -4, "mercy": -2}, "wrenModel": {"mercy": -1}, "wrenImpact": {"security": -4}, "reason": "betrayed Hollowmere's safety for outside advantage"},
	"goblin_favour:steal": {"player": {"personalLoyalty": -2, "mercy": -2}, "wrenModel": {"mercy": -1}, "wrenImpact": {"security": -2}, "reason": "preyed on Wren's community for a bargain"},
	"goblin_favour:raid_mine": {"player": {"personalLoyalty": -4, "mercy": -5}, "wrenModel": {"mercy": -2}, "wrenImpact": {"security": -4}, "reason": "used violence against neighbouring civilians for plunder"},
	"goblin_resolution:assault": {"player": {"personalLoyalty": 2, "mercy": -2}, "wrenModel": {"personalLoyalty": 2, "mercy": -2}, "wrenImpact": {"security": 2}, "reason": "protected Hollowmere through decisive violence"},
	"goblin_resolution:stealth_succession": {"player": {"personalLoyalty": 2, "mercy": 4}, "wrenModel": {"personalLoyalty": 1, "mercy": 4}, "wrenImpact": {"security": 3}, "reason": "found a restrained solution that still protected Hollowmere"},
	"goblin_resolution:goblin_diplomacy": {"player": {"personalLoyalty": 2, "mercy": 5}, "wrenModel": {"mercy": 4}, "wrenImpact": {"security": 2}, "reason": "solved a threat without needless bloodshed"},
	"goblin_resolution:goblin_alliance": {"player": {"personalLoyalty": -2, "mercy": 2}, "wrenImpact": {"security": -2}, "reason": "accepted continuing risk to Hollowmere to spare the tribe"},
	"goblin_resolution:betrayal": {"player": {"personalLoyalty": -12, "mercy": -8}, "wrenModel": {"personalLoyalty": 3, "mercy": -2}, "wrenImpact": {"security": -12}, "reason": "betrayed Wren's home despite travelling beside her"},
	"parents_search_promise": {"player": {"personalLoyalty": 2, "mercy": 1}, "wrenImpact": {"security": 1}, "reason": "promised to help with something deeply personal to Wren"},
	"parents_search_reached_millbrook": {"player": {"personalLoyalty": 5}, "wrenModel": {"personalLoyalty": 2}, "wrenImpact": {"security": 7}, "reason": "remembered and kept a personal promise to Wren"},
	"parents_investigation:support": {"player": {"personalLoyalty": 5, "mercy": 2}, "wrenModel": {"personalLoyalty": 3, "mercy": 2}, "wrenImpact": {"security": 7}, "reason": "put Wren's choice ahead of deciding her grief for her"},
	"parents_investigation:restore_names": {"player": {"personalLoyalty": -1, "mercy": 3}, "wrenModel": {"personalLoyalty": -2, "mercy": 3}, "wrenImpact": {"security": 6}, "reason": "answered private grief by restoring a public truth"},
	"parents_investigation:closure": {"player": {"mercy": 2}, "wrenModel": {"mercy": 1}, "wrenImpact": {"security": 4}, "reason": "helped Wren face the truth without directing what came next"},
	"player_became_lich": {"player": {"mercy": -20}, "wrenModel": {"mercy": -8}, "wrenImpact": {"security": -15}, "reason": "chose undeath despite what it would do to the people beside them"}
}
const DIALOGUE_CHOICES := {
	"people_do_not_give_up": {"player": {"personalLoyalty": 6, "mercy": 2}, "wrenModel": {"personalLoyalty": 6, "mercy": 2}, "wrenImpact": {"security": 2}, "relationship": {"approval": 2, "trust": 2, "familiarity": 1}, "reason": "told Wren that people should not give up on each other"},
	"loyalty_has_limits": {"player": {"personalLoyalty": -5, "mercy": 2}, "wrenModel": {"personalLoyalty": -6, "mercy": 2}, "wrenImpact": {"security": 5}, "relationship": {"approval": 1, "trust": 4, "familiarity": 2}, "reason": "told Wren that loyalty includes challenging someone who is wrong"},
	"look_after_our_own": {"player": {"personalLoyalty": 7, "mercy": -6}, "wrenModel": {"personalLoyalty": 6, "mercy": -5}, "wrenImpact": {"security": -1}, "relationship": {"approval": 1, "trust": 1, "familiarity": 1}, "reason": "told Wren that protecting your own matters more than outsiders"},
	"you_do_not_owe_me": {"player": {"personalLoyalty": -2, "mercy": 5}, "wrenModel": {"personalLoyalty": -3, "mercy": 3}, "wrenImpact": {"security": 10}, "relationship": {"approval": 3, "trust": 6, "familiarity": 3}, "reason": "made clear that Wren is free to stay because she chooses to"},
	"truth_even_when_it_hurts": {"player": {"personalLoyalty": -5, "mercy": 1}, "wrenModel": {"personalLoyalty": -5, "mercy": 1}, "wrenImpact": {"security": 3}, "relationship": {"trust": 2, "familiarity": 2}, "reason": "said that truth matters even when loyalty makes it painful"},
	"hurt_ours_no_second_chance": {"player": {"personalLoyalty": 5, "mercy": -8}, "wrenModel": {"personalLoyalty": 5, "mercy": -7}, "relationship": {"approval": 1, "familiarity": 1}, "reason": "argued that people who hurt your own forfeit mercy"},
	"do_not_become_them": {"player": {"mercy": 7}, "wrenModel": {"mercy": 7}, "wrenImpact": {"security": 4}, "relationship": {"trust": 3, "familiarity": 2}, "reason": "urged Wren not to let cruelty define her"},
	"power_keeps_us_safe": {"player": {"personalLoyalty": 3, "mercy": -5}, "wrenModel": {"personalLoyalty": 2, "mercy": -5}, "relationship": {"familiarity": 1}, "reason": "argued that power matters more than moral cleanliness when protecting your own"}
}

var player: Dictionary = PLAYER_START.duplicate(true)
var wren: Dictionary = WREN_START.duplicate(true)
var known_event_keys: Array[String] = []
var dialogue_choice_keys: Array[String] = []
var history: Array[Dictionary] = []

static func state_for(simulation: WorldSimulation) -> WrenCharacterArcState:
	if simulation == null:
		return null
	var existing: Variant = simulation.get_meta(META_KEY, null)
	if existing is WrenCharacterArcState:
		return existing
	var state := WrenCharacterArcState.new()
	simulation.set_meta(META_KEY, state)
	return state

func influence_scale(relationships: CompanionRelationshipState) -> float:
	if relationships == null:
		return 0.35
	var rel := relationships.snapshot("wren_talbot")
	return clampf(0.35 + float(rel.get("trust", 0.0)) / 200.0 + float(rel.get("familiarity", 0.0)) / 400.0, 0.35, 1.0)

func apply_story_event(event_key: String, relationships: CompanionRelationshipState) -> Dictionary:
	if not STORY_INFLUENCE.has(event_key):
		return {"ok": false, "reason": "unknown_story_event"}
	return _apply(event_key, STORY_INFLUENCE[event_key], "story", relationships)

func sync_story_events(relationships: CompanionRelationshipState) -> int:
	if relationships == null:
		return 0
	var wren_state: Dictionary = relationships.states.get("wren_talbot", {})
	var keys: Array = wren_state.get("known_event_keys", [])
	var applied := 0
	for key_value in keys:
		var key := String(key_value)
		if STORY_INFLUENCE.has(key):
			var result := apply_story_event(key, relationships)
			if bool(result.get("changed", false)):
				applied += 1
	return applied


func apply_dialogue_choice(choice_id: String, relationships: CompanionRelationshipState) -> Dictionary:
	if not DIALOGUE_CHOICES.has(choice_id):
		return {"ok": false, "reason": "unknown_dialogue_choice"}
	if dialogue_choice_keys.has(choice_id):
		return {"ok": true, "changed": false, "state": snapshot()}
	var result := _apply(choice_id, DIALOGUE_CHOICES[choice_id], "dialogue", relationships)
	if bool(result.get("ok", false)):
		dialogue_choice_keys.append(choice_id)
		var relationship_delta: Dictionary = DIALOGUE_CHOICES[choice_id].get("relationship", {})
		if not relationship_delta.is_empty() and relationships != null:
			relationships.record_event("wren_talbot", "character_arc_dialogue:" + choice_id, relationship_delta, String(DIALOGUE_CHOICES[choice_id].get("reason", "")))
	return result

func _apply(key: String, spec: Dictionary, source: String, relationships: CompanionRelationshipState) -> Dictionary:
	var stable_key := source + ":" + key
	if known_event_keys.has(stable_key):
		return {"ok": true, "changed": false, "state": snapshot()}
	var scale := influence_scale(relationships)
	_apply_deltas(player, spec.get("player", {}), 1.0)
	_apply_deltas(wren, spec.get("wrenModel", {}), scale)
	_apply_deltas(wren, spec.get("wrenImpact", {}), 1.0)
	known_event_keys.append(stable_key)
	var entry := {"key": stable_key, "reason": String(spec.get("reason", key)), "influence_scale": scale, "player": _axes(player, false), "wren": _axes(wren, true)}
	history.append(entry)
	if history.size() > 80:
		history.pop_front()
	return {"ok": true, "changed": true, "state": snapshot()}

func _apply_deltas(target: Dictionary, deltas: Dictionary, scale: float) -> void:
	for axis in ["personalLoyalty", "mercy", "security"]:
		if deltas.has(axis):
			var amount := float(deltas[axis]) * scale
			var rounded := roundi(amount)
			if rounded == 0 and amount != 0.0:
				rounded = 1 if amount > 0.0 else -1
			target[axis] = clampf(float(target.get(axis, 0.0)) + rounded, -100.0, 100.0)

func _axes(source: Dictionary, include_security: bool) -> Dictionary:
	var result := {"personalLoyalty": float(source.get("personalLoyalty", 0.0)), "mercy": float(source.get("mercy", 0.0))}
	if include_security:
		result["security"] = float(source.get("security", 0.0))
	return result

func snapshot() -> Dictionary:
	return {"player": _axes(player, false), "wren": _axes(wren, true), "stance": stance(), "attachment": attachment_state(), "history": history.duplicate(true)}

func stance() -> String:
	var loyal := float(wren.get("personalLoyalty", 0.0)) >= 25.0
	var principled := float(wren.get("personalLoyalty", 0.0)) <= -20.0
	var merciful := float(wren.get("mercy", 0.0)) >= 25.0
	var ruthless := float(wren.get("mercy", 0.0)) <= -20.0
	if loyal and ruthless: return "us_against_the_world"
	if loyal and merciful: return "steadfast_protector"
	if principled and merciful: return "principled_conscience"
	if principled and ruthless: return "hard_principlist"
	if ruthless: return "pragmatic_survivor"
	if merciful: return "compassionate_realist"
	return "unsettled"

func attachment_state() -> String:
	var security := float(wren.get("security", 0.0))
	if security >= 35.0: return "secure"
	if security <= -35.0: return "fear_bound"
	return "guarded"

func to_dict() -> Dictionary:
	return {"player": player.duplicate(true), "wren": wren.duplicate(true), "known_event_keys": known_event_keys.duplicate(), "dialogue_choice_keys": dialogue_choice_keys.duplicate(), "history": history.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	player = _normalise_axes(data.get("player", PLAYER_START), PLAYER_START)
	wren = _normalise_axes(data.get("wren", WREN_START), WREN_START)
	known_event_keys.clear()
	for key in data.get("known_event_keys", []):
		if not known_event_keys.has(String(key)): known_event_keys.append(String(key))
	dialogue_choice_keys.clear()
	for key in data.get("dialogue_choice_keys", []):
		if not dialogue_choice_keys.has(String(key)): dialogue_choice_keys.append(String(key))
	history.clear()
	for entry in data.get("history", []):
		if entry is Dictionary: history.append(entry.duplicate(true))

func _normalise_axes(value: Variant, defaults: Dictionary) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := defaults.duplicate(true)
	for key in defaults:
		result[key] = clampf(float(source.get(key, defaults[key])), -100.0, 100.0)
	return result
