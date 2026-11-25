class_name Campaign2SourceDialogueContent
extends RefCounted
## Dialogue migrated from Hex-crpg's campaign2Dialogue.js.
## This content layer owns authored words and conversational branches only;
## quest, faction, inventory and shop effects remain with their campaign services.

static func greeting_for_npc(dialogue_id: String, character: CharacterState, actor: Node3D, simulation: WorldSimulation) -> Dictionary:
	if character == null or simulation == null:
		return {}
	var journal := simulation.campaign_journal
	var guild_favor_state := journal.quest_state("guild_favor")
	var wizard_vendetta_state := journal.quest_state("wizard_vendetta")
	var dragon_state := journal.quest_state("millbrook_dragon")
	var goblin_state := journal.quest_state("goblin_threat")
	var goblin_decisions: Dictionary = goblin_state.get("decisions", {})
	var goblin_mine_state := journal.quest_state("goblin_mine_raid")
	var orc_trust_state := journal.quest_state("orc_stronghold_trust")
	var nix_state := simulation.get_character("nix_sharpear")
	var context := {
		"guild_favor_active": String(guild_favor_state.get("status", "")) == "active",
		"ironbond_influence": journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
		"ironbond_standing": journal.faction_standing("ironbond_company"),
		"wizard_resolution": String(wizard_vendetta_state.get("resolution", "")),
		"wizard_standing": journal.npc_standing("court_wizard_thessaly"),
		"millbrook_dragon_active": String(dragon_state.get("status", "")) == "active",
		"millbrook_dragon_completed": String(dragon_state.get("status", "")) == "completed",
		"goblin_resolution": String(goblin_state.get("resolution", goblin_decisions.get("resolution", ""))),
		"goblin_standing": journal.faction_standing("goblin_tribe"),
		"goblin_mine_raid_status": String(goblin_mine_state.get("status", "")),
		"orc_standing": journal.faction_standing("orc_raiders"),
		"orc_trust_active": String(orc_trust_state.get("status", "")) == "active",
		"orc_trust_completed": String(orc_trust_state.get("status", "")) == "completed",
		"nix_recruited": nix_state != null and nix_state.side == "player",
		"kingdom_standing": journal.faction_standing("silverhart_kingdom"),
		"thieves_guild_standing": journal.faction_standing("thieves_guild")
	}
	if dialogue_id in ["garrick_holt", "mira_ashbrook", "oskar_vinn", "wick_hallow", "yvette", "yvette_marlow", "hendra", "hendra_wells", "elder_marta", "marta_wynfield", "rowan_fletcher", "hollowmere_hunter", "tavern_patron", "bram_fenwick"]:
		var shakedown_state := journal.quest_state(HollowmereCampaignContent.QUEST_ID)
		var shakedown_decisions: Dictionary = shakedown_state.get("decisions", {})
		var shakedown_choice := String(shakedown_decisions.get("response", ""))
		var shakedown_resolved := String(shakedown_state.get("status", "")) == "completed"
		var standing := journal.npc_standing(dialogue_id)
		var hollowmere_conversation := HollowmereCampaignContent.npc_greeting(dialogue_id, shakedown_resolved, standing, shakedown_choice)
		if not hollowmere_conversation.is_empty():
			return hollowmere_conversation
	var conversation: Dictionary = greeting(dialogue_id, character.display_name, context)
	if conversation.is_empty():
		var title := String(actor.get_meta("title", "")) if actor != null else ""
		var ambient_role := String(actor.get_meta("ambient_role", "civilian")) if actor != null else "civilian"
		conversation = role_greeting(character.id, character.display_name, title, ambient_role)
	return conversation


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
			var wizard_resolution_value := String(context.get("wizard_resolution", ""))
			var personal_standing := float(context.get("wizard_standing", 0.0))
			var line := "The Queen keeps me for omens and old books, mostly — court wizardry is duller than the stories make it sound. Still, I read a great deal I probably shouldn't."
			if wizard_resolution_value == "wizard":
				line = "I haven't forgotten what you did for me. Ask, if you ever need it returned."
			elif not wizard_resolution_value.is_empty():
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
		"silverhart_general_goods":
			return {
				"speaker": display_name,
				"text": "Ordinary gear, honest prices — swords, shields, a decent helm, nothing fancy. The fancy stuff's a few doors down.",
				"choices": [
					{"id": "stock", "label": "What do travellers need most?", "text": "A sound blade, a shield that hasn't split, a spare helm and enough supplies to get to the next town. Nothing glamorous, but all of it useful."},
					{"id": "leave", "label": "Just looking.", "text": "The merchant gives you room to browse."}
				]
			}
		"silverhart_clothier":
			return {
				"speaker": display_name,
				"text": "Something for court, or something plainer for the road? Either way, it's all just for show — doesn't stop a blade any better than what you're already wearing.",
				"choices": [
					{"id": "court_clothes", "label": "What is suitable for court?", "text": "Something well cut, clean, and restrained. You want the court to notice you arrived, not spend the evening discussing your sleeves."},
					{"id": "leave", "label": "Not today.", "text": "The clothier folds the fabric neatly and waits for another customer."}
				]
			}
		"silverhart_magic_dealer":
			return {
				"speaker": display_name,
				"text": "Every piece here is genuine, and priced like it. Careful browsing — some of these will empty a purse fast.",
				"choices": [
					{"id": "wares", "label": "How do you judge a genuine piece?", "text": "Provenance, workmanship, and whether it still does what its maker intended. Most imitations fail at least two of those tests."},
					{"id": "leave", "label": "Just looking.", "text": "The dealer returns the item to its padded case."}
				]
			}
		"reddale_blacksmith":
			return {
				"speaker": display_name,
				"text": "Reddale's a waypoint, not a city — but the road wears down blades and armour same as anywhere. I keep enough stock to fix you up without a trip back to Hollowmere.",
				"choices": [
					{"id": "repairs", "label": "What can you repair?", "text": "Blades, armour, buckles, hinges — anything that can be made sound again with heat and a hammer. Bring it by in daylight."},
					{"id": "leave", "label": "Just looking.", "text": "The smith turns back to the forge."}
				]
			}
		"silverhart_stablehand":
			return {
				"speaker": display_name,
				"text": "Fine animals, every one — but they're wasted on someone who's never learned to sit a saddle. Come back once you've picked up Riding.",
				"choices": [
					{"id": "riding", "label": "What should I know before buying a horse?", "text": "Learn to ride first. A good horse is worth the price, but a poor rider can ruin a fine animal — or themselves."},
					{"id": "barding", "label": "Can horses be armoured?", "text": "Light barding is sensible for the road. Heavy armour has its place, but it changes how a horse moves and tires."},
					{"id": "leave", "label": "I'll be back.", "text": "The stablehand nods and returns to the horses."}
				]
			}

		"petra_hollis":
			if bool(context.get("millbrook_dragon_completed", false)):
				return {"speaker": display_name, "text": "Ashveil's gone, and good riddance. Sheep haven't slept easier in a generation. Millbrook won't forget it, traveler — nor will word stop there, I'd wager.", "choices": [{"id": "leave", "label": "Glad to help.", "text": "Petra gives you a grateful nod."}]}
			if bool(context.get("millbrook_dragon_active", false)):
				return {"speaker": display_name, "text": "Please tell me you're not going up there without a real plan. Ashveil's no wolf pack — that thing burned the Aldric barn to cinders and carried off half our flock in one night.", "choices": [{"id": "dragon", "label": "What do you know about Ashveil?", "text": "Something's nested out east in the high rocks. Nobody's seen it up close and lived to draw it proper, but we've seen what it leaves behind."}, {"id": "leave", "label": "I'll be careful.", "text": "Petra looks unconvinced."}]}
			return {"speaker": display_name, "text": "Don't get many travellers this far. Word is something's stirred up trouble on the road south of here — a house gone quiet, no one seen in or out for weeks. Nobody round here's brave enough to go look.", "choices": [{"id": "ashveil", "label": "What happened to the Aldric barn?", "text": "Something's nested out east in the high rocks. The Aldric barn is a scorch mark now, and we've lost more sheep than I can count."}, {"id": "quiet_house", "label": "What house has gone quiet?", "text": "South of here, along the road. No one has seen anyone come or go for weeks. Folk say it is nothing, but they say it from a safe distance."}, {"id": "leave", "label": "I'll keep an eye out.", "text": "Petra nods. She has already done all the worrying she can do from here."}]}
		"corran_vale":
			var corran_goblin_resolution := String(context.get("goblin_resolution", ""))
			if corran_goblin_resolution == "goblin_alliance":
				return {"speaker": display_name, "text": "Word reached us you've made peace with the Skarn-tooth tribe. Peace for Hollowmere, maybe — but they're still sitting right on our road, and I don't much trust it holding.", "choices": [{"id": "road", "label": "What would make the road safe?", "text": "A reliable agreement and a few wagons through without trouble. Until then, my crews will keep their distance."}, {"id": "leave", "label": "I'll keep watch.", "text": "Corran nods, though he remains wary."}]}
			if corran_goblin_resolution == "betrayal":
				return {"speaker": display_name, "text": "Whatever's happening with the goblins now, it's worse, not better. We've pulled everyone we can spare back behind the hall doors. Emberlode isn't shipping anything until this passes.", "choices": [{"id": "leave", "label": "Stay behind the doors.", "text": "Corran gives a grim nod."}]}
			return {"speaker": display_name, "text": "You're not from around here. Careful on that road — the Skarn-tooth tribe's dug in east of here, and they've taken three carts off us this month alone. Half my crew won't run it anymore.", "choices": [{"id": "goblins", "label": "How dangerous are the Skarn-tooth?", "text": "Dangerous enough that the carts stopped running. They took the ore, the strongbox, the lot. Nobody was killed, small mercy, but we've nothing left to move even if the road were safe."}, {"id": "leave", "label": "I'll keep an eye on the road.", "text": "Corran nods. He has heard promises before."}]}
		"emberlode_miner":
			var miner_resolution := String(context.get("goblin_resolution", ""))
			if miner_resolution == "goblin_alliance":
				return {"speaker": display_name, "text": "Settled with Hollowmere or not, that camp's still sitting right on our road. Doesn't fill me with confidence.", "choices": [{"id": "leave", "label": "Keep your head down.", "text": "The miner returns to the work."}]}
			if not miner_resolution.is_empty() and miner_resolution != "betrayal":
				return {"speaker": display_name, "text": "First good night's sleep I've had in a season, knowing the road's clear. Corran says we might even be back to full crews by next month.", "choices": [{"id": "leave", "label": "Good to hear.", "text": "The miner gives a tired smile."}]}
			return {"speaker": display_name, "text": "Ore's still in the ground same as ever — it's getting it out that's the trouble. Nobody wants to run the west road with the Skarn-tooth camp sitting right on it.", "choices": [{"id": "road", "label": "What is the mine short of?", "text": "Wagons, mostly. Ore is no good to anyone if it cannot leave the mountain."}, {"id": "leave", "label": "Take care.", "text": "The miner turns back to the seam."}]}
		"reddale_reeve":
			return {"speaker": display_name, "text": "The Ironbond Company sent a man 'round last week — talking protection fees, same as they did in Hollowmere by all accounts. I won't roll over for it, but I won't pretend saying no is free either. What would you do in my place?", "choices": [{"id": "resist", "label": "Push back against the Company.", "text": "Easy to say when it isn't your town on the line. Still, someone has to decide what sort of place Reddale is going to be."}, {"id": "negotiate", "label": "Try to broker a deal.", "text": "Perhaps. A deal can buy time, but the Company has a way of making temporary arrangements permanent."}, {"id": "leave", "label": "I can't decide that for you.", "text": "No. I suppose you can't."}]}
		"reddale_innkeeper":
			return {"speaker": display_name, "text": "Welcome to Reddale. Rooms are warm and the ale's better than the road food, I promise you that. Since you're asking after strange things — a family out past Millbrook way went quiet a season back, and a grave near here was found disturbed not long after. Everyone says animals. I'm not so sure they're the same kind of quiet.", "choices": [{"id": "blue_stone", "label": "Anything else worth knowing?", "text": "My mother always wore a blue stone, before we lost everything on the road here. If you ever find one out there, I'd pay well for it. Sentimental, I know."}, {"id": "grave", "label": "What happened at the grave?", "text": "The earth was turned, but nothing valuable was taken. Whatever did it wasn't looking for jewellery."}, {"id": "leave", "label": "I'll keep my ears open.", "text": "The innkeeper thanks you and returns to the common room."}]}
		"lady_corstane":
			return {"speaker": display_name, "text": "Court Wizard Thessaly has undermined my family at court one too many times. If you're capable of quiet work, find me something on her — the kind of thing she'd rather stayed buried. Do this, and House Corstane won't forget it.", "choices": [{"id": "ask_evidence", "label": "What sort of evidence do you need?", "text": "A record, a letter, a name — something that can withstand scrutiny. I will not risk my family on tavern gossip."}, {"id": "leave", "label": "I'll think about it.", "text": "Then think carefully. The court has a long memory."}]}
		"high_cleric":
			return {"speaker": display_name, "text": "The Grand Cathedral keeps the gods' peace over the whole kingdom — a bigger flock than Hollowmere's little chapel, but the same gods listening. Lately, though, something troubles me: reports from west of here, livestock found drained of blood rather than torn apart. Wolves don't drink, traveler. I fear something older is stirring.", "choices": [{"id": "livestock", "label": "What have the reports described?", "text": "Livestock found drained, not torn. Whatever is hunting there leaves little blood behind. I would know more before naming it."}, {"id": "leave", "label": "I'll watch for signs.", "text": "The cleric inclines his head."}]}
		"dwarven_ambassador":
			return {"speaker": display_name, "text": "The Deepholds trade in iron and good sense, in roughly that order. A trade toll of fifteen gold would smooth the road between us — nothing more than that, for now.", "choices": [{"id": "toll", "label": "Why a toll?", "text": "A road must be kept, and a promise must be worth something. Fifteen gold is a modest beginning for a lasting agreement."}, {"id": "leave", "label": "I'll consider it.", "text": "The ambassador nods, content to let the matter rest."}]}
		"aldenreach_ambassador":
			return {"speaker": display_name, "text": "Aldenreach and Silverhart haven't gone to war in three generations. My whole posting here is to keep it that way, one dull treaty dinner at a time. Would you carry a quiet word of goodwill to Hollowmere's elder for me? Nothing Silverhart needs to know about.", "choices": [{"id": "message", "label": "What should I tell Elder Marta?", "text": "Only that Aldenreach remembers its friends, and that the peace between our courts matters to us. No treaty, no demand — just goodwill."}, {"id": "leave", "label": "I'll think on it.", "text": "The ambassador returns to the correspondence."}]}
		"corvane_ambassador":
			return {"speaker": display_name, "text": "Corvane sent me to watch the greenskin trouble on Silverhart's border and report back. So far: it's trouble, and it's on the border. If you hear anything real out that way — anything I could actually put in a dispatch — I'd owe you.", "choices": [{"id": "border", "label": "What have you learned so far?", "text": "Not enough to write home with confidence. The camp west of Hollowmere is the centre of it, and the reports change with every traveller."}, {"id": "leave", "label": "I'll let you know.", "text": "The ambassador nods and makes a note."}]}


		"chief_skarnub":
			var chief_resolution_value := String(context.get("goblin_resolution", ""))
			if not chief_resolution_value.is_empty() and chief_resolution_value != "goblin_alliance":
				return {"speaker": display_name, "text": "We have nothing left to discuss.", "choices": [{"id": "leave", "label": "...", "text": "Skarnub turns away."}]}
			if chief_resolution_value == "goblin_alliance":
				if String(context.get("goblin_mine_raid_status", "")) == "completed":
					return {"speaker": display_name, "text": "We're settled here, thanks to you. That mine haul didn't hurt either.", "choices": [{"id": "leave", "label": "Good.", "text": "Skarnub gives a short nod."}]}
				return {"speaker": display_name, "text": "Since you've let us stay... there's a mining camp down the west road. Rich pickings, if you're willing to lead us there.", "choices": [{"id": "mine_raid", "label": "What is at the mining camp?", "text": "Emberlode's gold mine. A good haul would keep the tribe fed and armed. We can talk about it when the time is right."}, {"id": "leave", "label": "Not yet.", "text": "Skarnub waits, patient for a goblin."}]}
			if float(context.get("goblin_standing", 0.0)) >= 40.0:
				return {"speaker": display_name, "text": "You've done right by us. Truth told, this land's more trouble than it's worth — humans always come eventually. Guarantee us safe passage and supplies, and we'll move on. No more blood spilled, on either side.", "choices": [{"id": "passage", "label": "What would safe passage require?", "text": "Supplies enough to reach new ground, and a promise your people won't hunt us along the way. No more than that."}, {"id": "leave", "label": "Not yet.", "text": "Skarnub folds his arms and waits."}]}
			return {"speaker": display_name, "text": "Another human, come to gawk or to fight? Speak quick.", "choices": [{"id": "goblin_favour", "label": "I could help you, for the right price.", "text": "Hah. A human with sense. Bring me what I ask, and we'll get along fine."}, {"id": "read_chief", "label": "Try to read him.", "text": "Skarnub watches your hands more than your face. He is weighing whether you came empty-handed."}, {"id": "threaten", "label": "Leave this land, or face us.", "text": "Skarnub bares his teeth. \"Face us, then — see how far that gets you.\""}, {"id": "leave", "label": "Just looking.", "text": "Skarnub turns his attention back to the camp."}]}
		"nix_sharpear":
			var nix_goblin_resolution := String(context.get("goblin_resolution", ""))
			if nix_goblin_resolution == "goblin_alliance":
				if bool(context.get("nix_recruited", false)):
					return {"speaker": display_name, "text": "Still watching your back. What is it?", "choices": [{"id": "leave", "label": "Nothing, carry on.", "text": "Nix scans the edge of the camp."}]}
				return {"speaker": display_name, "text": "We're not going anywhere now — you saw to that. Skarnub speaks for us, but I never much liked sitting still watching a road. You're headed for more trouble than this camp's seen in years. Room for one more?", "choices": [{"id": "nix_story", "label": "Why did you want the tribe to move on?", "text": "Because a camp this close to a human village only ends one way. I wanted our people alive when the fighting started."}, {"id": "leave", "label": "Not yet.", "text": "Nix nods, neither offended nor surprised."}]}
			if not nix_goblin_resolution.is_empty():
				return {"speaker": display_name, "text": "We're already gone from here, or will be soon enough.", "choices": [{"id": "leave", "label": "Good.", "text": "Nix gives a curt nod."}]}
			return {"speaker": display_name, "text": "Something you need? Speak quick, this isn't a place for wandering humans.", "choices": [{"id": "why_watch", "label": "Why are you really this close to the village?", "text": "You think Skarnub chose this ground? We were told to sit here, watch the roads, count what comes and goes. Somebody's paying close attention to your precious Hollowmere, and it isn't us. I've said too much — forget I spoke."}, {"id": "leave", "label": "Just passing through.", "text": "Nix turns away, keeping one eye on you."}]}
		"goblin_trader":
			if float(context.get("goblin_standing", 0.0)) < 20.0:
				return {"speaker": display_name, "text": "Nothing for you here, human.", "choices": [{"id": "leave", "label": "...", "text": "The trader returns to sorting his goods."}]}
			return {"speaker": display_name, "text": "Ha! Ally's coin spends same as anyone's. Look, take, pay.", "choices": [{"id": "wares", "label": "What do you trade?", "text": "Axes, spears, armour, shields, torches and a few healing draughts. Nothing fancy, but it keeps a tribe alive."}, {"id": "leave", "label": "Just looking.", "text": "The trader grins and waits."}]}
		"orc_warlord":
			if bool(context.get("orc_trust_completed", false)):
				return {"speaker": display_name, "text": "Skarnak's Hold remembers who dealt with the troll. Kesh will trade with you properly now.", "choices": [{"id": "leave", "label": "Good to know.", "text": "Grukk gives a short, approving nod."}]}
			if bool(context.get("orc_trust_active", false)):
				return {"speaker": display_name, "text": "That troll still denning east of here? Deal with it and we'll talk properly.", "choices": [{"id": "troll", "label": "Where is its den?", "text": "East of the stockade, in the rocks. It has been picking off scouts and cattle. Bring proof that it is dead."}, {"id": "leave", "label": "I'm working on it.", "text": "Grukk folds his arms."}]}
			return {"speaker": display_name, "text": "Humans don't usually walk in here and expect to walk out. Something's been picking off our scouts and cattle east of the stockade — a troll, denned in the rocks. Kill it, and maybe you're worth talking to.", "choices": [{"id": "troll", "label": "What do you know about the troll?", "text": "It denns east of the stockade, in the rocks. It has been taking scouts and cattle. Deal with it and you'll have earned a proper welcome."}, {"id": "leave", "label": "Not interested.", "text": "Grukk's expression hardens."}]}
		"reddale_baron":
			return {"speaker": display_name, "text": "Reddale answers to me, same as the rest of the barony. Mind your business here and we'll get along fine. Bring a gift worth the visit and I'll remember it kindly — a fine red gem would do nicely.", "choices": [{"id": "barony", "label": "How fares the barony?", "text": "The roads are watched, the tariffs are collected, and the villages know who keeps order here. That is how a barony survives."}, {"id": "tribute", "label": "A red gem would please you?", "text": "A fine stone is a suitable tribute. It shows a visitor understands the difference between an audience and an entitlement."}, {"id": "leave", "label": "Understood.", "text": "The Baron turns his attention elsewhere."}]}
		"reddale_guildmaster":
			return {"speaker": display_name, "text": "The Guild looks after its own here in Reddale. Trade fair with us and we'll do the same for you.", "choices": [{"id": "guild", "label": "What does the Guild deal in?", "text": "Information, opportunity, and the occasional problem that needs solving quietly. What matters is knowing who to trust."}, {"id": "leave", "label": "Good to know.", "text": "Petra Voss returns to her business."}]}
		"thieves_guildmaster":
			if float(context.get("thieves_guild_standing", 0.0)) < 0.0:
				return {"speaker": display_name, "text": "You've got some nerve, showing your face here after that. Walk away while you still can.", "choices": [{"id": "leave", "label": "...", "text": "Corvin Ashe watches until you turn away."}]}
			if float(context.get("thieves_guild_standing", 0.0)) >= 50.0:
				return {"speaker": display_name, "text": "You've earned your place here. What do you need?", "choices": [{"id": "guild_work", "label": "Anything worth knowing?", "text": "There's always work for someone who knows when to speak and when to keep quiet."}, {"id": "leave", "label": "Just checking in.", "text": "Corvin nods once."}]}
			return {"speaker": display_name, "text": "You've done right by us so far. Keep it that way.", "choices": [{"id": "guild_work", "label": "Is there work for me?", "text": "Earn the Guild's trust and there will be. We don't hand out opportunities to strangers."}, {"id": "leave", "label": "Understood.", "text": "Corvin turns back to his accounts."}]}
		"elven_ambassador":
			return {"speaker": display_name, "text": "The Sylvan Court sends its regards to the Queen, and its patience with her borders' woodcutters. Both are finite, in their way. A gift of good herbs would go some way toward the latter — three, if you can spare them.", "choices": [{"id": "elven_herbs", "label": "Why herbs?", "text": "The Court values the living things of the forest. A gift gathered with care carries more meaning than a purse of gold."}, {"id": "leave", "label": "I'll keep that in mind.", "text": "Ambassador Elarion returns to his correspondence."}]}
		"ironbond_envoy":
			var influence := float(context.get("ironbond_influence", 30.0))
			var envoy_line := "Business as usual — a little coin here, a little influence there. Nothing you'd need to worry about."
			if influence >= 60.0:
				envoy_line = "The Company's word carries real weight in this court these days. We like it that way."
			elif influence <= 10.0:
				envoy_line = "Harder going for us at court lately, if I'm honest. Someone's been undoing our work."
			return {"speaker": display_name, "text": envoy_line + " There's a general store out in Hollowmere — Wick Hallow's place. Convince him to carry Ironbond stock and there's coin in it for you.", "choices": [{"id": "company", "label": "How is the Company faring?", "text": envoy_line}, {"id": "leave", "label": "Noted.", "text": "Factor Willem Drass returns to his accounts."}]}
		"orc_trader":
			if float(context.get("orc_standing", 0.0)) < 20.0:
				return {"speaker": display_name, "text": "Nothing for you here, human.", "choices": [{"id": "leave", "label": "...", "text": "Kesh turns back to his wares."}]}
			return {"speaker": display_name, "text": "Coin's coin. What do you need?", "choices": [{"id": "wares", "label": "What do you trade?", "text": "Axes, spears, clubs, medium armour, shields, torches and healing potions. Pay fair and we get along."}, {"id": "leave", "label": "Just looking.", "text": "Kesh nods once."}]}
		_:
			return {}


static func role_greeting(character_id: String, display_name: String, title: String, ambient_role: String) -> Dictionary:
	var role := ambient_role.to_lower()
	var title_key := title.to_lower()
	if role == "civilian" or role.is_empty():
		if title_key.contains("guard") or title_key.contains("watch") or title_key.contains("captain"):
			role = "guard"
		elif title_key.contains("merchant") or title_key.contains("shop") or title_key.contains("innkeeper") or title_key.contains("factor") or title_key.contains("trader"):
			role = "merchant"
		elif title_key.contains("miner") or title_key.contains("smith") or title_key.contains("blacksmith"):
			role = "miner"
		elif title_key.contains("cleric") or title_key.contains("priest") or title_key.contains("chapel"):
			role = "clergy"
		elif title_key.contains("farmer") or title_key.contains("herder") or title_key.contains("stable"):
			role = "farmer"
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
				{"text": "This is a small place, but there's always something happening if you know where to look.", "reply": "What sort of thing?", "response": "The sort folk stop talking about when strangers come close."},
				{"text": "You passing through, or thinking of staying?", "reply": "Still deciding.", "response": "Then take your time. The roads will still be here tomorrow."},
				{"text": "People have been asking more questions lately. Usually means something is about to change.", "reply": "What have you heard?", "response": "Only fragments. The useful bits rarely travel with the loud ones."}
			]
	var variant_index := posmod(character_id.hash(), variants.size())
	var selected: Dictionary = variants[variant_index]
	return {
		"speaker": display_name,
		"text": String(selected.get("text", "")),
		"choices": [
			{"id": "role_topic", "label": String(selected.get("reply", "Tell me more.")), "text": String(selected.get("response", ""))},
			{"id": "leave", "label": "Good day.", "text": "They return to their duties."}
		]
	}
