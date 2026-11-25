class_name GoblinThreatCampaignRuntimeService
extends RefCounted
## Runtime bridge between the source-authored Skarn-tooth content and the
## persistent campaign simulation. Dialogue data stays in content classes.

const CONTENT_SCRIPT = preload("res://scripts/simulation/goblin_threat_campaign_content.gd")
const FOLLOWUP_SCRIPT = preload("res://scripts/simulation/goblin_threat_followup_content.gd")
const WORLD_EFFECT_SERVICE = preload("res://scripts/simulation/campaign_world_effect_service.gd")
const SCOUT_NOTE_QUEST_ID := "goblin_scout_note"


static func give_chief_gift(simulation: WorldSimulation, relationships: PersistentCharacterRelationshipState) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    var player := simulation.get_character(simulation.player_character_id)
    if player == null:
        return {"ok": false, "reason": "missing_player"}
    var content := CONTENT_SCRIPT.new()
    var result := content.give_chief_gift(relationships, player.gold)
    if not bool(result.get("ok", false)):
        return result
    player.gold = int(result.get("gold_remaining", player.gold))
    return result


static func begin_favour_negotiation(simulation: WorldSimulation) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    return CONTENT_SCRIPT.new().begin_favour_negotiation(simulation.campaign_journal)


static func resolve_threat(
    simulation: WorldSimulation,
    resolution: String,
    relationships: PersistentCharacterRelationshipState = null,
    scene_tree: SceneTree = null,
    local_actor_by_id: Dictionary = {}
) -> Dictionary:
    if simulation == null or simulation.campaign_journal == null:
        return {"ok": false, "reason": "missing_simulation"}
    var journal := simulation.campaign_journal
    var result: Dictionary = CONTENT_SCRIPT.new().resolve_threat(journal, resolution, relationships)
    if not bool(result.get("ok", false)) or not bool(result.get("applied", false)):
        return result
    var effects: Dictionary = result.get("effects", {})
    var applied := WORLD_EFFECT_SERVICE.apply_effects(
        journal, simulation, CONTENT_SCRIPT.QUEST_ID, "resolution", effects, scene_tree, local_actor_by_id
    )
    if not bool(applied.get("ok", false)):
        return {"ok": false, "reason": "world_effect_application_failed", "detail": applied, "resolution": resolution}
    result["world_effects"] = applied
    return result


static func resolve_favour(
    simulation: WorldSimulation,
    favour: String,
    scene_tree: SceneTree = null,
    local_actor_by_id: Dictionary = {}
) -> Dictionary:
    if simulation == null or simulation.campaign_journal == null:
        return {"ok": false, "reason": "missing_simulation"}
    var journal := simulation.campaign_journal
    var result: Dictionary = CONTENT_SCRIPT.new().resolve_favour(journal, favour)
    if not bool(result.get("ok", false)) or not bool(result.get("applied", false)):
        return result
    var decision_id := "resolution" if result.has("resolution") else "favour_" + favour
    var effects: Dictionary = result.get("effects", {})
    var applied := WORLD_EFFECT_SERVICE.apply_effects(
        journal, simulation, CONTENT_SCRIPT.QUEST_ID, decision_id, effects, scene_tree, local_actor_by_id
    )
    if not bool(applied.get("ok", false)):
        return {"ok": false, "reason": "world_effect_application_failed", "detail": applied, "favour": favour}
    result["world_effects"] = applied
    return result


static func read_scout_note(simulation: WorldSimulation) -> Dictionary:
    if simulation == null or simulation.campaign_journal == null:
        return {"ok": false, "reason": "missing_simulation"}
    var journal := simulation.campaign_journal
    var already_read := bool(journal.world_campaign_flag("goblin_scout_note_read", false))
    var result: Dictionary = FOLLOWUP_SCRIPT.new().read_scout_note({"goblin_scout_note_read": already_read})
    if bool(result.get("already_read", false)):
        return result
    if not journal.quest_definitions.has(SCOUT_NOTE_QUEST_ID):
        var registered := journal.register_quest_definition({
            "id": SCOUT_NOTE_QUEST_ID,
            "title": "The Goblin Scout's Note",
            "description": "Read the oilcloth map found in the Skarn-tooth camp.",
            "objectives": []
        })
        if not bool(registered.get("ok", false)):
            return registered
    if not journal.quests.has(SCOUT_NOTE_QUEST_ID):
        var started := journal.start_quest(SCOUT_NOTE_QUEST_ID)
        if not bool(started.get("ok", false)):
            return started
    var decision := journal.record_decision(SCOUT_NOTE_QUEST_ID, "read_note", "read")
    if not bool(decision.get("ok", false)):
        return decision
    var applied := WORLD_EFFECT_SERVICE.apply_effects(
        journal, simulation, SCOUT_NOTE_QUEST_ID, "read_note", result.get("effects", {})
    )
    if not bool(applied.get("ok", false)):
        return applied
    result["world_effects"] = applied
    return result


static func nix_greeting(simulation: WorldSimulation) -> Dictionary:
    if simulation == null:
        return {}
    var journal := simulation.campaign_journal
    var quest: Dictionary = journal.quest_state(CONTENT_SCRIPT.QUEST_ID)
    var context := {
        "quest_resolution": String(quest.get("decisions", {}).get("resolution", "")),
        "chief_assassinated": bool(journal.world_campaign_flag("skarnub_assassinated", false)),
        "nix_recruited": simulation.is_party_member(FOLLOWUP_SCRIPT.NIX_ID)
    }
    return FOLLOWUP_SCRIPT.new().nix_greeting(context)


static func nix_patron_response(question: String = "why") -> Dictionary:
    return FOLLOWUP_SCRIPT.new().nix_patron_response(question)


static func grondle_greeting(simulation: WorldSimulation) -> Dictionary:
    if simulation == null:
        return {}
    var quest: Dictionary = simulation.campaign_journal.quest_state(CONTENT_SCRIPT.QUEST_ID)
    var context := {"quest_resolution": String(quest.get("decisions", {}).get("resolution", ""))}
    return FOLLOWUP_SCRIPT.new().grondle_greeting(context)


static func aldric_captive_greeting(simulation: WorldSimulation) -> Dictionary:
    if simulation == null:
        return {}
    var context := {
        "aldric_recruited": simulation.is_party_member(FOLLOWUP_SCRIPT.ALDRIC_ID),
        "aldric_rescued": bool(simulation.campaign_journal.world_campaign_flag("aldric_rescued", false))
    }
    return FOLLOWUP_SCRIPT.new().aldric_captive_greeting(context)
