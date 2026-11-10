class_name CompanionCampaignContent
extends RefCounted
## Source-derived first-contact dialogue and recruitment gates for the eight
## original campaign companions. Quest completion is event-driven: map/combat
## systems call complete_objective when the relevant world event exists.

const DEFINITIONS := [
    {"id":"goblin_threat","title":"The Skarn-tooth Tribe","description":"Resolve the goblin threat. Nix Sharpear joins only if the tribe is peacefully allied.","objectives":[{"id":"resolved","description":"Resolve the goblin threat and choose the goblin alliance.","target":1.0,"required":true}]},
    {"id":"goblin_threat","title":"The Skarn-tooth Tribe","description":"Resolve the goblin threat. Nix Sharpear joins only if the tribe is peacefully allied.","objectives":[{"id":"resolved","description":"Resolve the goblin threat and choose the goblin alliance.","target":1.0,"required":true}]},
    {"id":"star_fort_companion","title":"A Choice at Star Fort","description":"Resolve the Star Fort encounter and choose the greenskin alliance; Snik Fangtooth will then offer to join.","objectives":[{"id":"greenskin_resolution","description":"Choose the greenskin side at Star Fort.","target":1.0,"required":true}]},
    {"id":"aldric_rescue","title":"A Debt at the Goblin Camp","description":"Find Ser Aldric Thorne captive at the goblin camp and free him.","objectives":[{"id":"freed","description":"Free Ser Aldric from captivity.","target":1.0,"required":true}]},
    {"id":"orc_stronghold_trust","title":"Prove Your Strength","description":"Deal with the troll denning east of Skarnak's Hold and earn the orc stronghold's trust.","objectives":[{"id":"troll_slain","description":"Defeat the troll threatening the orc scouts and cattle.","target":1.0,"required":true}]},
    {"id":"reyna_bear_hunt","title":"The Grain-Raiding Bear","description":"Help Reyna Fletcher stop the bear raiding Old Mac's grain stores.","objectives":[{"id":"bear_slain","description":"Defeat the bear at Old Mac's Farmstead.","target":1.0,"required":true}]},
    {"id":"mirabel_spider_ruin","title":"The Ruin's Quiet","description":"Clear the spider nest at the nearby ruin so Mirabel can recover what is inside.","objectives":[{"id":"nest_cleared","description":"Defeat the spiders guarding the ruin.","target":1.0,"required":true}]},
    {"id":"fenn_herb_gathering","title":"Three Bundles for the Grove","description":"Gather three bundles of herbs for Fenn Oakheart.","objectives":[{"id":"herbs_delivered","description":"Deliver three bundles of herbs to Fenn.","target":3.0,"required":true}]},
    {"id":"northwatch_siege","title":"Hold Northwatch","description":"Help defend Northwatch. Brother Alden will consider joining after the battle.","objectives":[{"id":"defended","description":"Resolve the Northwatch siege in the defenders' favour.","target":1.0,"required":true}]},
]

const PROFILES := {
    "ser_aldric_thorne":{"name":"Ser Aldric Thorne","quest":"aldric_rescue"},
    "nix_sharpear":{"name":"Nix Sharpear","quest":"goblin_threat"},
    "warlord_grukk_ironhide":{"name":"Warlord Grukk Ironhide","quest":"orc_stronghold_trust"},
    "reyna_fletcher":{"name":"Reyna Fletcher","quest":"reyna_bear_hunt"},
    "mirabel_quill":{"name":"Mirabel Quill","quest":"mirabel_spider_ruin"},
    "fenn_oakheart":{"name":"Fenn Oakheart","quest":"fenn_herb_gathering"},
    "brother_alden":{"name":"Brother Alden","quest":"northwatch_siege"},
    "snik_fangtooth":{"name":"Snik Fangtooth","quest":"star_fort_companion"}
}

static func is_companion_id(character_id: String) -> bool:
    return PROFILES.has(character_id)

static func is_companion_id(character_id: String) -> bool:
    return PROFILES.has(character_id)

static func register_quest_definitions(journal: CampaignJournal) -> void:
    if journal == null:
        return
    for definition_value in DEFINITIONS:
        var definition: Dictionary = definition_value
        if not journal.quest_definitions.has(String(definition.id)):
            journal.register_quest_definition(definition)

static func complete_with_decision(journal: CampaignJournal, quest_id: String, objective_id: String, decision_id: String, choice_id: String) -> Dictionary:
    if journal == null:
        return {"ok":false,"reason":"missing_journal"}
    var decision := journal.record_decision(quest_id, decision_id, choice_id)
    if not bool(decision.get("ok", false)):
        return decision
    return complete_objective(journal, quest_id, objective_id)

static func complete_with_decision(journal: CampaignJournal, quest_id: String, objective_id: String, decision_id: String, choice_id: String) -> Dictionary:
    if journal == null:
        return {"ok":false,"reason":"missing_journal"}
    var decision := journal.record_decision(quest_id, decision_id, choice_id)
    if not bool(decision.get("ok", false)):
        return decision
    return complete_objective(journal, quest_id, objective_id)

static func complete_objective(journal: CampaignJournal, quest_id: String, objective_id: String) -> Dictionary:
    if journal == null:
        return {"ok":false,"reason":"missing_journal"}
    var progress := journal.set_objective_progress(quest_id, objective_id, 1.0)
    if not bool(progress.get("ok", false)):
        return progress
    var completion := journal.complete_quest(quest_id)
    if not bool(completion.get("ok", false)):
        return completion
    return {"ok":true,"quest_id":quest_id,"objective_id":objective_id}

static func _state(journal: CampaignJournal, quest_id: String) -> Dictionary:
    return journal.quest_state(quest_id) if journal != null else {}

static func _completed(journal: CampaignJournal, quest_id: String) -> bool:
    return String(_state(journal, quest_id).get("status", "")) == "completed"

static func _started(journal: CampaignJournal, quest_id: String) -> bool:
    return not _state(journal, quest_id).is_empty()

static func _choice(id: String, label: String, available: bool = true, reason: String = "") -> Dictionary:
    return {"id":id,"label":label,"available":available,"unavailable_reason":reason}

static func conversation(character_id: String, journal: CampaignJournal, inventory: Array[Dictionary], party_ids: Array[String]) -> Dictionary:
    var profile: Dictionary = PROFILES.get(character_id, {})
    if profile.is_empty():
        return {}
    var name := String(profile.name)
    var quest_id := String(profile.quest)
    if party_ids.has(character_id):
        return {"speaker":name,"text":"Good to have you with us. What do you need?","choices":[_choice("continue","Carry on.")]}
    var state := _state(journal, quest_id)
    var choices: Array[Dictionary] = []
    var body := ""
    var recruit_ready := false
    match character_id:
        "ser_aldric_thorne":
            body = "Please... cut me loose. I came out here to deal with this goblin problem myself, and, well — here we are. Whatever you decide to do about them, I intend to see them gone from this land. I'll owe you a debt either way."
            recruit_ready = _completed(journal, quest_id)
            if recruit_ready:
                body = "You kept your word and got me out. I owe you a debt, and I would rather repay it at your side than sit idle. Will you have me?"
            elif not _started(journal, quest_id):
                choices.append(_choice("start:"+quest_id,"I'll find you at the goblin camp and free you."))
            else:
                body = "I am still waiting on that goblin camp. Find me there and cut me loose; then we can speak of travelling together."
        "nix_sharpear":
            body = "Something you need? Speak quick, this isn't a place for wandering humans. You think Skarnub chose this ground? We were told to sit here, watch the roads, count what comes and goes. Somebody's paying close attention to Hollowmere, and it isn't us."
            var goblin_state := _state(journal, "goblin_threat")
            var resolution := String(goblin_state.get("decisions", {}).get("resolution", ""))
            recruit_ready = String(goblin_state.get("status", "")) == "completed" and resolution == "goblin_alliance"
            if recruit_ready:
                body = "We're not going anywhere now — you saw to that. Skarnub speaks for us, but I never much liked sitting still watching a road. You're headed for more trouble than this camp's seen in years. Room for one more?"
            else:
                choices.append(_choice("continue","Who told you to watch the village?"))
                choices.append(_choice("continue","I'll leave you to it."))
        "warlord_grukk_ironhide":
            var reputation := journal.faction_standing("orc_raiders") if journal != null else 0.0
            recruit_ready = _completed(journal, quest_id) and reputation >= 40.0
            if recruit_ready:
                body = "Skarnak's Hold remembers who dealt with the troll, and Kesh trades with you properly now — but I've had my fill of sitting behind a stockade counting raids. There's more out there worth breaking than trolls. Room for a warlord at your back?"
            elif _completed(journal, quest_id):
                body = "The troll is dealt with. Skarnak's Hold remembers it, and Kesh trades with you properly now. Earn the hold's deeper trust before asking me to leave it."
            elif _started(journal, quest_id):
                body = "That troll still denning east of Skarnak's Hold? Deal with it and we'll talk properly."
            else:
                body = "Humans don't usually walk in here and expect to walk out. Something's been picking off our scouts and cattle east of the stockade — a troll, denned in the rocks. Kill it, and maybe you're worth talking to."
                choices.append(_choice("start:"+quest_id,"I'll deal with the troll."))
        "reyna_fletcher":
            recruit_ready = _completed(journal, quest_id)
            if recruit_ready:
                body = "That's the last of it dead, then. Good riddance — it's cost Old Mac more grain than he can spare. I owe you for the help. I've been meaning to travel further than these woods for a while now — mind the company?"
            elif _started(journal, quest_id):
                body = "That bear is still raiding Old Mac's grain stores. Help me finish it and I might just travel on with you afterward."
            else:
                body = "Careful — there's a bear gone bold, raiding the grain stores at night. I've been tracking it a few days now. Help me finish it and I might just travel on with you afterward."
                choices.append(_choice("start:"+quest_id,"I'll help with the bear."))
        "mirabel_quill":
            recruit_ready = _completed(journal, quest_id)
            if recruit_ready:
                body = "The nest's cleared, then — I felt them go quiet from here. Whatever's still readable in there is mine now, and I owe you for the opening. I travel light and I don't stay anywhere long, but I could use a steadier direction for a while."
            elif _started(journal, quest_id):
                body = "There's a ruin nearby with something in it worth reading — old enough to matter. Spiders have made a nest of the entrance, though, and I'm no fighter. Clear them out and whatever's inside is worth knowing about."
            else:
                body = "There's a ruin nearby with something in it worth reading — old enough to matter, if the rumours are even half true. Spiders have made a nest of the entrance, though, and I'm no fighter. Clear them out and whatever's inside is worth knowing about."
                choices.append(_choice("start:"+quest_id,"I'll clear out the ruin."))
        "fenn_oakheart":
            var herb_count := _count_item(inventory, "herbs")
            recruit_ready = _started(journal, quest_id) and herb_count >= 3
            if recruit_ready:
                body = "Three bundles, gathered clean — you've got a feel for this place. The grove doesn't need me the way it used to. I think I'm ready to see more of the world than these trees."
                choices.append(_choice("recruit:"+character_id,"Give the herbs, and join me."))
            else:
                body = "The Elder keeps the grove's peace; I mostly just gather. Bring me three bundles of herbs from the patches here and I'll know you respect the place, not just what grows in it. You have %d of the three bundles." % herb_count
                if not _started(journal, quest_id):
                    choices.append(_choice("start:"+quest_id,"I'll gather some herbs."))
        "brother_alden":
            recruit_ready = _completed(journal, quest_id)
            if recruit_ready:
                body = "Brother Alden lowers his guard, breathing hard but very much alive. 'Brother Alden, of the Silverhart monastery — posted here to help hold the wall. And hold it we did, thanks to you. I've nowhere pressing to be, and I don't much fancy more garrison duty after this. Would you have me along?'"
            elif _started(journal, quest_id):
                body = "The fighting at Northwatch is not finished. Help the garrison hold the wall, and then we'll speak."
            else:
                body = "I'm Brother Alden, of the Silverhart monastery. I'm posted at Northwatch to help hold the wall. If the siege comes, stand with us — then we'll see what comes after."
        "snik_fangtooth":
            var fort_state := _state(journal, quest_id)
            recruit_ready = String(fort_state.get("status", "")) == "completed" and String(fort_state.get("decisions", {}).get("side", "")) == "greenskin"
            if recruit_ready:
                body = "You chose the greenskin side at Star Fort. I was hoping you would. There's more out there than another fort wall. Room for one more?"
            else:
                body = "Name's Snik Fangtooth. I have no interest in picking a side before you do. When Star Fort comes, choose the greenskin cause and we'll talk."
    if recruit_ready and character_id != "fenn_oakheart":
        choices.append(_choice("recruit:"+character_id,"Join us."))
        choices.append(_choice("continue","Not right now."))
    if choices.is_empty():
        choices.append(_choice("continue","Understood."))
    return {"speaker":name,"text":body,"choices":choices}

static func _count_item(inventory: Array[Dictionary], item_id: String) -> int:
    var count := 0
    for item in inventory:
        if String(item.get("id", "")) == item_id:
            count += int(item.get("quantity", 1))
    return count

static func consume_item(inventory: Array[Dictionary], item_id: String, amount: int) -> bool:
    if amount <= 0 or _count_item(inventory, item_id) < amount:
        return false
    var remaining := amount
    for index in range(inventory.size() - 1, -1, -1):
        if String(inventory[index].get("id", "")) != item_id:
            continue
        var quantity := int(inventory[index].get("quantity", 1))
        var take := mini(quantity, remaining)
        if take == quantity:
            inventory.remove_at(index)
        else:
            inventory[index]["quantity"] = quantity - take
        remaining -= take
        if remaining <= 0:
            break
    return true
