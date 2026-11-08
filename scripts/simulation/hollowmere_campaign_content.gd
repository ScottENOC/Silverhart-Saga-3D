class_name HollowmereCampaignContent
extends RefCounted
## Source-backed opening dialogue and ambient exchanges for Campaign 2 / Hollowmere.
## Text is migrated from Hex-crpg campaign2Dialogue.js and ambientChatterExpansion.js.

const QUEST_ID := "hollowmere_ironbond_shakedown"

static func shakedown_quest_definition() -> Dictionary:
    return {
        "id": QUEST_ID,
        "title": "Ironbond's Due",
        "description": "The Ironbond Company has come to collect its monthly due from Garrick Holt.",
        "objectives": [
            {"id": "response", "description": "Decide how to respond to the Ironbond shakedown.", "target": 1.0, "required": true}
        ]
    }


static func opening_lines() -> Array[Dictionary]:
    return [
        {"speaker_id": "narrator", "speaker": "Narrator", "text": "The tavern door bangs open. Three armed men in matching colours stride in, eyes on the bar."},
        {"speaker_id": "dray_coltayne", "speaker": "Dray Coltayne", "text": "Evening, Garrick. Ironbond Company's monthly due is past collecting. You know how this goes."},
        {"speaker_id": "garrick_holt", "speaker": "Garrick Holt", "text": "Business has been slow, Sergeant. Can it wait 'til the week's end?"},
        {"speaker_id": "dray_coltayne", "speaker": "Dray Coltayne", "text": "It can't. Pay up, or this place finds out what an 'accident' looks like."}
    ]


static func shakedown_choices() -> Array[Dictionary]:
    return [
        {
            "id": "stay_out",
            "label": "Stay out of it.",
            "response": "Garrick pays up, shoulders slumped. The soldiers leave with their due.",
            "ironbond_delta": 5,
            "arc_side": "",
            "available": true
        },
        {
            "id": "encourage_pay",
            "label": "Tell Garrick to pay — and back it with a threat.",
            "response": "You back the demand with a hard stare. The soldiers take their due and leave without further trouble.",
            "ironbond_delta": 15,
            "arc_side": "ironbond",
            "available": true
        },
        {
            "id": "fight",
            "label": "Side with Garrick. Fight them.",
            "response": "",
            "ironbond_delta": -35,
            "arc_side": "crown",
            "available": false,
            "unavailable_reason": "The encounter AI and attack-targeting interface are not yet connected to this opening."
        }
    ]


static func resolve_shakedown(journal: CampaignJournal, choice_id: String) -> Dictionary:
    if journal == null:
        return {"ok": false, "reason": "missing_journal"}
    var selected: Dictionary = {}
    for choice_value in shakedown_choices():
        var choice: Dictionary = choice_value
        if String(choice.get("id", "")) == choice_id and bool(choice.get("available", true)):
            selected = choice
            break
    if selected.is_empty():
        return {"ok": false, "reason": "choice_unavailable"}
    var decision := journal.record_decision(QUEST_ID, "response", choice_id)
    if not bool(decision.get("ok", false)):
        return decision
    journal.set_objective_progress(QUEST_ID, "response", 1.0)
    journal.adjust_faction_standing("ironbond_company", int(selected.get("ironbond_delta", 0)), "Hollowmere shakedown: " + choice_id)
    var arc_side := String(selected.get("arc_side", ""))
    if not arc_side.is_empty():
        journal.record_decision(QUEST_ID, "ironbond_arc_side", arc_side)
    var completion := journal.complete_quest(QUEST_ID)
    if not bool(completion.get("ok", false)):
        return completion
    return {"ok": true, "choice": selected.duplicate(true)}

static func npc_greeting(npc_id: String, shakedown_resolved: bool) -> Dictionary:
    match npc_id:
        "garrick_holt":
            if shakedown_resolved:
                return {
                    "speaker": "Garrick Holt",
                    "text": "Thanks again for that, friend. The Tankard's doors are always open to you.",
                    "choices": [
                        {"id": "news", "label": "What's the word around here?", "text": "Quiet, lately. Same faces, same ale. I'll take it — quiet's been hard-earned around here."},
                        {"id": "leave", "label": "Glad to help.", "text": "Garrick gives you a grateful nod."}
                    ]
                }
            return {
                "speaker": "Garrick Holt",
                "text": "Welcome to the Hollow Tankard! Sit, drink, rest a while.",
                "choices": [
                    {"id": "ironbond", "label": "What's Ironbond's hold over this place?", "text": "They call it a monthly due. Everyone else calls it protection money. I can't afford to refuse them."},
                    {"id": "news", "label": "What's the word around here?", "text": "Quiet, lately. Same faces, same ale. I'll take it — quiet's been hard-earned around here."},
                    {"id": "leave", "label": "Thanks, we will.", "text": "Garrick turns back to the bar."}
                ]
            }
        "mira_ashbrook":
            return {
                "speaker": "Mira Ashbrook",
                "text": "Quiet little village, Hollowmere. Most days, anyway.",
                "choices": [
                    {"id": "news", "label": "Any news from further out?", "text": "My cousin rode with the Silverhart levy up to the borderlands, fighting off orc raiders. Last letter said the raids have gotten worse — bigger warbands than the old stories tell. I try not to think on it too much."},
                    {"id": "leave", "label": "Good to know.", "text": "Mira nods and returns to her thoughts."}
                ]
            }
        "oskar_vinn":
            return {
                "speaker": "Oskar Vinn",
                "text": "First time in Hollowmere? Mind the Ironbond lot if they're about.",
                "choices": [
                    {"id": "spar", "label": "Care to spar? Friendly bout.", "text": "Ha! Thought you'd never ask. Don't hold back on my account."},
                    {"id": "news", "label": "Heard anything worth knowing?", "text": "The levies keep marching north. Orc raiders on the border, apparently — worse than usual this year."},
                    {"id": "leave", "label": "Noted.", "text": "Oskar gives you a nod."}
                ]
            }
        "companion_wren_talbot":
            return {"speaker": "Wren Talbot", "text": "Well, here we are then. Try not to get us both killed, yeah?", "choices": [{"id": "leave", "label": "I'll do my best.", "text": "Wren grins."}]}
        _:
            return {"speaker": npc_id.replace("_", " ").capitalize(), "text": "The villager gives you a polite nod.", "choices": [{"id": "leave", "label": "Good day.", "text": "They return to what they were doing."}]}


static func ambient_exchanges() -> Array[Dictionary]:
    return [
        {"id":"daily_pie","topic":"daily-life","roles":["any"],"lines":["You still owe me for that pie.","I dispute the word 'owe'.","You ate it.","I dispute nothing else."]},
        {"id":"roof_leak","topic":"daily-life","roles":["any"],"lines":["Your roof still leaking?","Only when it rains.","That's generally when roofs matter."]},
        {"id":"lost_boot","topic":"daily-life","roles":["any"],"lines":["I lost a boot this morning.","How do you lose one boot?","If I knew that, I'd know where it was."]},
        {"id":"goat_trouble","topic":"daily-life","roles":["any"],"lines":["You look tired.","I was awake for most of the night.","Trouble?","Goat."]},
        {"id":"hens_union","topic":"daily-life","roles":["any"],"lines":["Your hens laying again?","One is. The others have formed a union."]},
        {"id":"weather_clouds","topic":"weather","roles":["any"],"lines":["Clouds are sitting low.","Good. Saves them the trouble of falling far."]},
        {"id":"weather_rain","topic":"weather","roles":["any"],"lines":["Rain before dusk, I reckon.","Your knee telling you?","No. The enormous black cloud."]},
        {"id":"work_inspection","topic":"work","roles":["any"],"lines":["You taking a break?","I'm conducting a detailed inspection of this wall."]},
        {"id":"work_long_day","topic":"work","roles":["any"],"lines":["Long day?","It became a long day shortly after breakfast."]},
        {"id":"ale_cider","topic":"food","roles":["any"],"lines":["Ale or cider?","Whichever one someone else is buying."]},
        {"id":"turnip_ale","topic":"food","roles":["any"],"lines":["They put turnip in everything lately.","Not everything.","Name one thing.","Ale.","Give them time."]},
        {"id":"guard_watch","topic":"guard-business","roles":["guard"],"lines":["Quiet watch?","Don't say that. That's how trouble hears you."]},
        {"id":"hollowmere_tankard","topic":"hollowmere-local","roles":["any"],"lines":["Tankard busy tonight?","Garrick says every empty stool is resting for later."]},
        {"id":"hollowmere_river","topic":"hollowmere-local","roles":["any"],"lines":["River's high by the landing.","Good for fish. Bad for boots."]},
        {"id":"ironbond_aftermath","topic":"ironbond-aftermath","roles":["any"],"requires_shakedown":true,"priority":8,"lines":["Still strange not seeing Ironbond swagger through here.","Strange good, or strange dangerous?","Ask me when we know what fills the space."]},
        {"id":"security_low","topic":"security","roles":["any"],"security_below":30,"priority":9,"lines":["Bar the shutters before dark.","Again?","Until the road feels safe again, yes."]},
        {"id":"security_high","topic":"security","roles":["any"],"security_above":65,"priority":6,"lines":["Road's felt calmer lately.","Don't praise a quiet road where it can hear you."]},
        {"id":"morning","topic":"time","roles":["any"],"hour_start":5,"hour_end":9,"lines":["You're up early.","I object to both words in that sentence."]},
        {"id":"midday","topic":"time","roles":["any"],"hour_start":11,"hour_end":14,"lines":["Lunch?","In theory.","Best kind. No washing up."]},
        {"id":"night","topic":"time","roles":["any"],"hour_start":21,"hour_end":5,"lines":["You heading home?","Soon as my feet remember the route."]}
    ]
