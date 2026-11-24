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

const WHY_STAY_CHOICE_IDS := ["people_do_not_give_up", "loyalty_has_limits", "look_after_our_own", "you_do_not_owe_me"]
const PARENTS_REFLECTION_CHOICE_IDS := ["truth_even_when_it_hurts", "hurt_ours_no_second_chance", "do_not_become_them", "power_keeps_us_safe"]
const DIALOGUE_LABELS := {
	"people_do_not_give_up": "“People shouldn’t give up on each other just because things get hard.”",
	"loyalty_has_limits": "“Loyalty has limits. If I’m wrong, I need you to tell me.”",
	"look_after_our_own": "“You look after your own. Everyone else comes second.”",
	"you_do_not_owe_me": "“You don’t owe me staying. If you stay, I want it to be because you choose to.”",
	"truth_even_when_it_hurts": "“The truth matters, even when it hurts people we care about.”",
	"hurt_ours_no_second_chance": "“People who hurt ours don’t automatically deserve a second chance.”",
	"do_not_become_them": "“Don’t let cruel people decide who you become.”",
	"power_keeps_us_safe": "“What happened proves why we need enough power that nobody can do that to ours again.”"
}
const DIALOGUE_RESPONSES := {
	"people_do_not_give_up": "“Yeah. That’s more or less the rule I’ve been living by.”",
	"loyalty_has_limits": "Wren studies you. “Careful. I might take that as permission.”",
	"look_after_our_own": "“Our own,” Wren repeats. “Dangerous little phrase, that. I can see the appeal.”",
	"you_do_not_owe_me": "For once Wren has no quick answer. “...All right. I’ll try to remember that.”",
	"truth_even_when_it_hurts": "“Then I suppose I’d better get used to saying uncomfortable things.”",
	"hurt_ours_no_second_chance": "Wren nods slowly. “No. Maybe they don’t.”",
	"do_not_become_them": "“That sounds annoyingly sensible.” A pause. “I’ll think about it.”",
	"power_keeps_us_safe": "“Power as insurance.” Wren frowns. “I hate that I understand the argument.”"
}


func why_stays_line(relationships: CompanionRelationshipState) -> String:
	var rel: Dictionary = relationships.snapshot("wren_talbot") if relationships != null else {}
	var trust := float(rel.get("trust", 0.0))
	var security := float(wren.get("security", 0.0))
	var loyalty := float(wren.get("personalLoyalty", 0.0))
	var mercy := float(wren.get("mercy", 0.0))
	if trust <= 10.0:
		if loyalty >= 25.0:
			return "“Because leaving someone when they’re at their worst is still leaving them. Don’t mistake that for me thinking you’re right.”"
		return "“Because if everyone who remembers who you were walks away, who exactly is left to tell you when you’ve become a monster?”"
	if security >= 35.0 and loyalty >= 20.0:
		return "“I used to think staying was something I had to prove. It isn’t. I’m here because I choose you. There’s a difference.”"
	if loyalty >= 40.0 and mercy <= -15.0:
		return "“The world gets very generous with rules when it’s somebody else bleeding. I know who mine are. You’re one of them.”"
	if loyalty <= -20.0:
		return "“Staying doesn’t mean agreeing. Sometimes loyalty is being the one person who’ll stand close enough to tell you no.”"
	if security <= -30.0:
		return "Wren looks away. “People disappear. They promise they won’t, and then one day there’s just an empty chair. I suppose I decided a long time ago I wouldn’t be the empty chair.”"
	return "“People leave. I don’t. Maybe that’s stubbornness, maybe it’s a character flaw. You’ve travelled with me long enough to know I’ve got both.”"


func parents_reflection_line() -> String:
	var loyalty := float(wren.get("personalLoyalty", 0.0))
	var mercy := float(wren.get("mercy", 0.0))
	var security := float(wren.get("security", 0.0))
	if mercy >= 25.0 and security >= 20.0:
		return "“Finding out what happened didn’t make me want revenge as much as I thought it would. Mostly I don’t want Venn to get to decide what sort of person I become.”"
	if mercy <= -20.0 and loyalty >= 25.0:
		return "“I keep thinking about how many people knew enough to be suspicious and chose quiet. I don’t think I have much patience left for people who hurt ours and ask for understanding after.”"
	if loyalty <= -20.0:
		return "“They deserved more than someone quietly caring about them. They deserved somebody willing to say what happened out loud, even when powerful people wanted silence.”"
	return "“I thought knowing would settle something. It did, sort of. Mostly it left me deciding what I want the knowing to do to me.”"


func dialogue_topics(relationships: CompanionRelationshipState, journal: CampaignJournal) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var rel: Dictionary = relationships.snapshot("wren_talbot") if relationships != null else {}
	if float(rel.get("familiarity", 0.0)) >= 35.0:
		var why_label := "Why are you still here?" if float(rel.get("trust", 0.0)) <= 10.0 else "Why do you always stay?"
		options.append({"id":"wren_arc_topic:why_stay","label":why_label})
	var parents_completed := journal != null and String(journal.quest_state("wren_parents").get("status", "")) == "completed"
	if parents_completed:
		options.append({"id":"wren_arc_topic:parents_reflection","label":"What did finding your parents change for you?"})
	return options


func dialogue_options_for_topic(topic_id: String) -> Array[Dictionary]:
	var ids: Array = WHY_STAY_CHOICE_IDS if topic_id == "why_stay" else PARENTS_REFLECTION_CHOICE_IDS
	for choice_id_value in ids:
		if dialogue_choice_keys.has(String(choice_id_value)):
			var follow_up_label := "I’m glad you’re here." if topic_id == "why_stay" else "Whatever comes next, we’ll face it."
			return [{"id":"continue","label":follow_up_label,"text":""}]
	var options: Array[Dictionary] = []
	for choice_id_value in ids:
		var choice_id := String(choice_id_value)
		options.append({"id":"wren_arc_choice:" + choice_id,"label":String(DIALOGUE_LABELS.get(choice_id, choice_id))})
	return options

func dialogue_response_for(choice_id: String) -> String:
	return String(DIALOGUE_RESPONSES.get(choice_id, "Wren considers your words for a moment."))


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
