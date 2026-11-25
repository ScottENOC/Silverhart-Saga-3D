class_name Campaign2SourceDialogueContent
extends RefCounted
## Dialogue migrated from Hex-crpg's campaign2Dialogue.js.
## This content layer owns authored words and conversational branches only;
## quest, faction, inventory and shop effects remain with their campaign services.

static func greeting(dialogue_id: String, display_name: String, context: Dictionary = {}) -> Dictionary:
    match dialogue_id:
        "palace_chancellor":
            return {
                "speaker": display_name,
                "text": "Her Majesty's ledgers, her letters, her patience with petitioners — all mine to mind, in that order. If you've business with the crown, best it's brief.",
                "choices": [
                    {"id": "border_news", "label": "What's the news from the borderlands?", "text": "Nothing Her Majesty says in open court, if that's what you're asking. Orc raids past Aldervale, worse than the old stories — that much everyone already knows. What worries me is how organized they've gotten. Raiders don't usually keep to a plan."},
                    {"id": "leave", "label": "No business today.", "text": "Then I shall return to the ledgers. They are less demanding than most petitioners."}
                ]
            }
        "reddale_guard":
            return {
                "speaker": display_name,
                "text": "Captain Rennick runs the watch here — if there's work needs doing, she's the one to ask. Me, I just mind the gate.",
                "choices": [
                    {"id": "gate_news", "label": "Anything unusual on the road?", "text": "A few more travellers than usual, and fewer willing to say where they've been. Captain Rennick keeps the watch informed; best take anything serious to her."},
                    {"id": "leave", "label": "Noted.", "text": "The watchman returns his attention to the gate."}
                ]
            }
        "reddale_steward":
            return {
                "speaker": display_name,
                "text": "The Baron is occupied. State your business, or don't waste my time.",
                "choices": [
                    {"id": "baron_business", "label": "I have business with the Baron.", "text": "Then be precise. His lordship has little patience for rambling visitors."},
                    {"id": "leave", "label": "Never mind.", "text": "The steward gives a curt nod and turns away."}
                ]
            }
        "reddale_captain":
            return {
                "speaker": display_name,
                "text": "Something on your mind?",
                "choices": [
                    {"id": "watch_report", "label": "What is the watch seeing on the roads?", "text": "More movement north of Aldervale. The reports don't agree on numbers, but they agree on one thing: the raiding parties are better organised than they used to be."},
                    {"id": "cult_report", "label": "I've heard troubling rumours about a cult.", "text": "Then bring me something more than rumour. A name, a place, a witness — anything I can put in a report and act on."},
                    {"id": "leave", "label": "Never mind.", "text": "Captain Rennick returns to her duties."}
                ]
            }
        "reddale_disciple":
            return {
                "speaker": display_name,
                "text": "Herbs for a cough, a bad hip, a bad night's sleep — that's all I sell. Anything else?",
                "choices": [
                    {"id": "herbs", "label": "What remedies do you recommend?", "text": "For a cough, thyme and honey. For a bad hip, warmth and rest. For a bad night's sleep, fewer questions and an earlier bed."},
                    {"id": "leave", "label": "Nothing, thanks.", "text": "She returns to sorting the dried herbs."}
                ]
            }
        "thieves_guild_informant":
            return {
                "speaker": display_name,
                "text": "Don't know what you've heard, but I'm nobody. Just a man minding his own business.",
                "choices": [
                    {"id": "leave", "label": "...", "text": "He looks away and finds something else to occupy his attention."}
                ]
            }
        "thieves_guild_debtor":
            var favor := bool(context.get("guild_favor_active", false))
            if favor:
                return {
                    "speaker": display_name,
                    "text": "Look, I know why you're here. I just need more time, I—",
                    "choices": [
                        {"id": "guild_debt", "label": "Corvin Ashe sent me. Pay up.", "text": "...Corvin. Right. Here — take it, just don't let him send anyone worse next time."},
                        {"id": "leave", "label": "I'll give you another day.", "text": "He lets out a breath, though he still looks worried."}
                    ]
                }
            return {
                "speaker": display_name,
                "text": "Whatever you're selling, I'm not buying. And whatever I owe, I don't have it. Move along.",
                "choices": [{"id": "leave", "label": "...", "text": "He turns his back on you."}]
            }
        "ironbond_merchant":
            var influence := float(context.get("ironbond_influence", 0.0))
            var standing := float(context.get("ironbond_standing", 0.0))
            if influence < 40.0:
                return {
                    "speaker": display_name,
                    "text": "We're still finding our feet out here. Come back once the Company's better established in these parts.",
                    "choices": [{"id": "leave", "label": "I'll check back.", "text": "The merchant returns to his accounts."}]
                }
            if standing < 20.0:
                return {
                    "speaker": display_name,
                    "text": "The Company doesn't arm strangers. Prove you're worth the trust and we'll talk.",
                    "choices": [{"id": "leave", "label": "Understood.", "text": "The merchant's expression does not change."}]
                }
            return {
                "speaker": display_name,
                "text": "Ironbond doesn't stock what the crown's armourers do — we stock what they can't get anymore.",
                "choices": [
                    {"id": "wares", "label": "What makes your stock different?", "text": "Supply, mostly. The Company has routes and contacts the crown would rather pretend don't exist."},
                    {"id": "leave", "label": "Just looking.", "text": "The merchant nods once."}
                ]
            }
        "royal_wizard":
            var resolution := String(context.get("wizard_resolution", ""))
            var personal_standing := float(context.get("wizard_standing", 0.0))
            var line := "The Queen keeps me for omens and old books, mostly — court wizardry is duller than the stories make it sound. Still, I read a great deal I probably shouldn't."
            if resolution == "wizard":
                line = "I haven't forgotten what you did for me. Ask, if you ever need it returned."
            elif not resolution.is_empty():
                line = "You're a citizen of this kingdom, and I'll extend you the courtesy that demands — nothing warmer than that. Don't mistake civility for forgiveness."
            elif personal_standing < -10.0:
                line = "The crown speaks well of you, for whatever that's worth to me personally. I have my own opinion, and it isn't as generous."
            return {
                "speaker": display_name,
                "text": line,
                "choices": [
                    {"id": "wizard_lore", "label": "Anything worth sharing?", "text": "There are old records in the tower that speak of powers better left undisturbed. Most are warnings. A few are invitations, which is rather worse."},
                    {"id": "leave", "label": "Another time.", "text": "The wizard returns to her reading."}
                ]
            }
        "builder_tomas":
            return {
                "speaker": display_name,
                "text": "Name it and I'll build it, so long as you bring the materials — or the coin to cover them.",
                "choices": [
                    {"id": "materials", "label": "What sort of materials do you need?", "text": "Timber for frames and roofs, stone for foundations, and iron fittings where the work needs to last. Bring the right stock and I can make something useful of it."},
                    {"id": "leave", "label": "I'll come back when I'm ready.", "text": "I'll be here. Good work takes materials, time, and a bit of patience."}
                ]
            }
        _:
            return {}


static func role_greeting(character_id: String, display_name: String, title: String, ambient_role: String) -> Dictionary:
    var role := ambient_role.to_lower()
    var variants: Array[Dictionary] = []
    match role:
        "guard":
            variants = [
                {"text": "Keep your eyes on the road. Most trouble gives you warning; the clever sort tries not to.", "reply": "I'll remember that.", "response": "Good. Remembering is cheaper than replacing a helmet."},
                {"text": "Quiet shift, for once. I'm trying not to draw attention to it.", "reply": "Expecting trouble?", "response": "No. That's why I'm not saying the word out loud."},
                {"text": "If you're looking for the captain, try the watch post. I'm only holding this stretch of wall.", "reply": "Anything I should know?", "response": "Keep to the main road after dusk. That's all."}
            ]
        "merchant":
            variants = [
                {"text": "If you're buying, I can help. If you're only browsing, try not to touch the fragile things.", "reply": "How is trade?", "response": "Uneven. Folk still need supplies; they just think twice before spending."},
                {"text": "Prices change faster than the weather these days. At least the weather gives warning.", "reply": "What's selling?", "response": "Things that last: oil, rope, salt, and anything a traveller can carry."},
                {"text": "A good customer knows what they need before they ask. A great one knows what they can afford.", "reply": "Sound advice.", "response": "Expensive advice, if you ask the wrong merchant."}
            ]
        "miner":
            variants = [
                {"text": "The mine never really goes quiet. Even when the picks stop, the mountain keeps settling.", "reply": "Is that safe?", "response": "Safe enough if you know which sounds to listen for."},
                {"text": "Dust gets into everything. Food, clothes, lungs. You learn to live with it, or find another trade.", "reply": "Worth the work?", "response": "The ore is worth something. Whether the work is, depends on the day."},
                {"text": "Hard rock, decent ore, bad language. That's an honest day's work.", "reply": "I'll leave you to it.", "response": "A sensible choice."}
            ]
        "clergy":
            variants = [
                {"text": "The shrine is open to anyone who comes in peace. The gods have heard worse than a traveller's worries.", "reply": "Do people come often?", "response": "More often when life becomes difficult. I try not to judge the timing."},
                {"text": "A quiet prayer can steady the mind. It cannot mend a roof, but it may help you climb up and do it.", "reply": "Practical wisdom.", "response": "The practical sort tends to last."}
            ]
        "farmer":
            variants = [
                {"text": "Fields need tending whether the roads are safe or not. Crops don't wait for soldiers.", "reply": "How is the harvest?", "response": "Ask me again when it's in. Before then, the field is full of promises."},
                {"text": "The animals know when trouble is near. They get restless before the rest of us do.", "reply": "Anything worrying them?", "response": "Nothing I can put a name to. Yet."}
            ]
        _:
            variants = [
                {"text": "Hollowmere's a small place, but there's always something happening if you know where to look.", "reply": "What sort of thing?", "response": "The sort folk stop talking about when strangers come close."},
                {"text": "You passing through, or thinking of staying?", "reply": "Still deciding.", "response": "Then take your time. The roads will still be here tomorrow."},
                {"text": "People have been asking more questions lately. Usually means something is about to change.", "reply": "What have you heard?", "response": "Only fragments. The useful bits rarely travel with the loud ones."}
            ]
    var variant_index := posmod(character_id.hash(), variants.size())
    var selected: Dictionary = variants[variant_index]
    var resolved_title := title.strip_edges()
    return {
        "speaker": display_name,
        "text": String(selected.get("text", "")) if resolved_title.is_empty() else String(selected.get("text", "")),
        "choices": [
            {"id": "role_topic", "label": String(selected.get("reply", "Tell me more.")), "text": String(selected.get("response", ""))},
            {"id": "leave", "label": "Good day.", "text": "They return to their duties."}
        ]
    }
