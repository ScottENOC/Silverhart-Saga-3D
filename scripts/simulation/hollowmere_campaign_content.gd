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
			"available": true
		}
	]


static func initialize_social_standings(journal: CampaignJournal, player_race: String = "human") -> void:
	if journal == null:
		return
	var normalized_race := player_race.to_lower()
	var human_standing := 5.0 if normalized_race == "human" else 0.0
	if normalized_race == "goblin" or normalized_race == "orc":
		human_standing = -15.0
	journal.seed_npc_reputation("garrick_holt", human_standing, 0.0)
	journal.seed_npc_reputation("mira_ashbrook", human_standing, 0.0)
	journal.seed_npc_reputation("oskar_vinn", human_standing, 0.0)
	journal.seed_npc_reputation("hollowmere_elder", human_standing, 0.0)
	journal.seed_npc_reputation("hollowmere_baron", human_standing, 0.0)
	journal.seed_faction_reputation("ironbond_company", human_standing, 0.0)
	journal.seed_faction_reputation("silverhart_kingdom", human_standing, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)


static func _cascade_reputation(journal: CampaignJournal, standing_delta: float, knowledge_delta: float, reason: String) -> void:
	var falloff := 0.4
	var authority_ids: Array[String] = ["garrick_holt", "hollowmere_elder", "hollowmere_baron"]
	for index in range(authority_ids.size()):
		var multiplier := pow(falloff, index)
		journal.adjust_npc_reputation(authority_ids[index], standing_delta * multiplier, knowledge_delta * multiplier, reason)
	var kingdom_multiplier := pow(falloff, authority_ids.size())
	journal.adjust_faction_reputation("silverhart_kingdom", standing_delta * kingdom_multiplier, knowledge_delta * kingdom_multiplier, reason)


static func apply_shakedown_choice(journal: CampaignJournal, choice_id: String) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	initialize_social_standings(journal)
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
	var reason := "Hollowmere shakedown: " + choice_id
	match choice_id:
		"stay_out":
			_cascade_reputation(journal, -10.0, 10.0, reason)
			journal.adjust_npc_reputation("mira_ashbrook", -5.0, 5.0, reason)
			journal.adjust_npc_reputation("oskar_vinn", -5.0, 5.0, reason)
			journal.adjust_faction_reputation("ironbond_company", 5.0, 5.0, reason)
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", 1.0, reason)
		"encourage_pay":
			_cascade_reputation(journal, 5.0, 15.0, reason)
			journal.adjust_npc_reputation("mira_ashbrook", 0.0, 10.0, reason)
			journal.adjust_npc_reputation("oskar_vinn", 0.0, 10.0, reason)
			journal.adjust_faction_reputation("ironbond_company", 15.0, 15.0, reason)
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", 2.0, reason)
		"fight":
			_cascade_reputation(journal, 25.0, 20.0, reason)
			journal.adjust_npc_reputation("mira_ashbrook", 20.0, 20.0, reason)
			journal.adjust_npc_reputation("oskar_vinn", 20.0, 20.0, reason)
			journal.adjust_faction_reputation("ironbond_company", -35.0, 25.0, reason)
			journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", -2.0, reason)
	var arc_side := String(selected.get("arc_side", ""))
	if not arc_side.is_empty():
		journal.record_decision(QUEST_ID, "ironbond_arc_side", arc_side)
	return {"ok": true, "choice": selected.duplicate(true)}


static func complete_shakedown(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	return journal.complete_quest(QUEST_ID)


static func resolve_shakedown(journal: CampaignJournal, choice_id: String) -> Dictionary:
	var result := apply_shakedown_choice(journal, choice_id)
	if not bool(result.get("ok", false)):
		return result
	if choice_id == "fight":
		return result
	var completion := complete_shakedown(journal)
	if not bool(completion.get("ok", false)):
		return completion
	return result


static func shakedown_victory_text() -> String:
	return "It's over... thank you. I didn't think anyone would stand with us against the Company."


static func npc_greeting(npc_id: String, shakedown_resolved: bool, npc_standing: float = 0.0, shakedown_choice: String = "") -> Dictionary:
	match npc_id:
		"garrick_holt":
			if shakedown_resolved and shakedown_choice == "fight":
				return {
					"speaker": "Garrick Holt",
					"text": "You stood up to them when the rest of us were afraid to. The Tankard won't forget it.",
					"choices": [
						{"id": "news", "label": "What's the word around here?", "text": "Word travels. Some folk think Ironbond will come back harder; others reckon they have learned Hollowmere won't bend so easily."},
						{"id": "leave", "label": "You'd have done the same.", "text": "Garrick shakes his head. He wishes he had found the courage sooner."}
					]
				}
			if shakedown_resolved and shakedown_choice == "encourage_pay":
				return {
					"speaker": "Garrick Holt",
					"text": "You made your position clear. I won't pretend I liked it, but at least the Company left without breaking the place.",
					"choices": [
						{"id": "news", "label": "What's the word around here?", "text": "People are keeping their heads down. No one wants to be the next example."},
						{"id": "leave", "label": "It could have been worse.", "text": "Garrick looks back to the bar. Aye, it could have."}
					]
				}
			if shakedown_resolved and shakedown_choice == "stay_out":
				return {
					"speaker": "Garrick Holt",
					"text": "You stood aside while they took my money. I understand why, but I won't pretend it did not sting.",
					"choices": [
						{"id": "news", "label": "What's the word around here?", "text": "People are keeping their heads down. No one wants to be the next example."},
						{"id": "leave", "label": "I am sorry.", "text": "Garrick gives a small nod and turns back to the bar."}
					]
				}
			if shakedown_resolved:
				return {
					"speaker": "Garrick Holt",
					"text": "Thanks for not making things worse, friend. The Tankard's doors are still open to you.",
					"choices": [
						{"id": "news", "label": "What's the word around here?", "text": "Quiet, lately. Same faces, same ale. I'll take it — quiet's been hard-earned around here."},
						{"id": "leave", "label": "Glad to help.", "text": "Garrick gives you a tired nod."}
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
			var mira_text := "Quiet little village, Hollowmere. Most days, anyway."
			if npc_standing >= 20:
				mira_text = "I heard what happened with Ironbond. It took courage to stand with Garrick. I only hope they do not return with more men."
			elif shakedown_choice == "fight":
				mira_text = "I heard what happened with Ironbond. It took courage to stand with Garrick. I only hope they do not return with more men."
			elif shakedown_choice == "encourage_pay":
				mira_text = "I heard you backed the Company. Maybe that kept the peace today, but it leaves a bitter taste."
			elif shakedown_choice == "stay_out":
				mira_text = "Garrick paid them in the end. I can't blame anyone for keeping their head down, but it shouldn't have to be this way."
			return {
				"speaker": "Mira Ashbrook",
				"text": mira_text,
				"choices": [
					{"id": "news", "label": "Any news from further out?", "text": "My cousin rode with the Silverhart levy up to the borderlands, fighting off orc raiders. Last letter said the raids have gotten worse — bigger warbands than the old stories tell. I try not to think on it too much."},
					{"id": "leave", "label": "Good to know.", "text": "Mira nods and returns to her thoughts."}
				]
			}
		"oskar_vinn":
			var oskar_text := "First time in Hollowmere? Mind the Ironbond lot if they're about."
			if npc_standing >= 20:
				oskar_text = "Heard you took on Ironbond. Not a bad scrap, by the sound of it. Shame I missed it."
			elif shakedown_choice == "fight":
				oskar_text = "Heard you took on Ironbond. Not a bad scrap, by the sound of it. Shame I missed it."
			elif shakedown_choice == "encourage_pay":
				oskar_text = "So you stood with the Company. Practical, perhaps. Doesn't make them any more welcome."
			elif shakedown_choice == "stay_out":
				oskar_text = "Can't say I blame you for staying out of it. Three armed men aren't an easy argument."
			return {
				"speaker": "Oskar Vinn",
				"text": oskar_text,
				"choices": [
					{"id": "spar", "label": "Care to spar? Friendly bout.", "text": "Ha! Thought you'd never ask. Don't hold back on my account." , "available": false, "unavailable_reason": "The duel encounter is not connected to the 3D combat interface yet."},
					{"id": "news", "label": "Heard anything worth knowing?", "text": "The levies keep marching north. Orc raiders on the border, apparently — worse than usual this year."},
					{"id": "leave", "label": "Noted.", "text": "Oskar gives you a nod."}
				]
			}
		"wick_hallow":
			return {
				"speaker": "Wick Hallow",
				"text": "Welcome to Hallow's Goods. Soldier-grade gear, fair prices — what's left of my stock, anyway.",
				"choices": [
					{"id": "supplies", "label": "What sells well around here?", "text": "Lamp oil, rope, salt and anything that keeps in a pack. Folk buy more of those when the roads turn rough."},
					{"id": "delivery", "label": "Heard you've had some trouble.", "text": "A goblin scout snatched a delivery of mine not far from here — south and west of the shop. Little thing, shouldn't be hard to catch, but I can't leave the counter to do it myself."},
					{"id": "news", "label": "Heard any news?", "text": "Caravans are taking the longer road. No one says why unless they have had a drink or three."},
					{"id": "leave", "label": "Just looking.", "text": "Wick nods and resumes sorting his shelves."}
				]
			}
		"yvette", "yvette_marlow":
			return {
				"speaker": "Yvette Marlow",
				"text": "Oh — sorry, didn't mean to stare. My boy Tomas went off with the border levy three months back. Fighting orc raiders up past Aldervale.",
				"choices": [
					{"id": "tomas_letter", "label": "Have you heard from him?", "text": "A letter, once, back in Brightsun. Said the raids were getting worse — more of them, better organized than the raiding parties used to be. Nothing since. I try to tell myself the roads are just slow this time of year."},
					{"id": "sympathy", "label": "I'm sorry to hear that.", "text": "Thank you. It's the waiting that's hardest. At least when he's on the road, I can imagine he's still moving."},
					{"id": "leave", "label": "I'll let you be.", "text": "Yvette gives you a small, grateful smile."}
				]
			}
		"hendra", "hendra_wells":
			return {
				"speaker": "Hendra Wells",
				"text": "My boy Tam's always off exploring — never listens. But it's been since yesterday, and he always comes home by dark. He was headed out past the crossroads, west along the old road.",
				"choices": [
					{"id": "tam_last_seen", "label": "Where was he headed?", "text": "West, past the crossroads. He knows not to go near the old ruins, but Tam has never been good at listening."},
					{"id": "tam_reassure", "label": "I'll keep an eye out for him.", "text": "Please, if you find anything out there, come straight back to me. I don't care what time it is."},
					{"id": "leave", "label": "I'm sure he'll be home soon.", "text": "Hendra tries to smile, but keeps glancing towards the road."}
				]
			}
		"elder_marta", "marta_wynfield":
			var marta_text := "Welcome, traveler. Hollowmere's a small place, but an honest one."
			if shakedown_resolved and shakedown_choice == "fight":
				marta_text = "Word of what you did at the Tankard reached me. Hollowmere doesn't forget a favor like that."
			elif shakedown_resolved and shakedown_choice == "stay_out":
				marta_text = "I heard about the Tankard. Garrick's a proud man — I imagine that stung him more than you know."
			elif shakedown_resolved and shakedown_choice == "encourage_pay":
				marta_text = "The Ironbond men were in the village again. Nothing's changed there, I'm afraid."
			return {
				"speaker": "Elder Marta Wynfield",
				"text": marta_text,
				"choices": [
					{"id": "ironbond", "label": "What can be done about Ironbond?", "text": "They call it a monthly due. Everyone else calls it protection money. A village can endure a great deal, but it should not have to live at another company's mercy."},
					{"id": "border", "label": "What news from the border?", "text": "The levy riders say the orc warbands are growing larger and better organised. I would rather not frighten the village with rumours, but we should be ready."},
					{"id": "village", "label": "How is the village holding up?", "text": "We are still here. People look after one another, even when they disagree about what is best. That matters more than most folk realise."},
					{"id": "leave", "label": "Thank you, Elder.", "text": "Marta inclines her head and returns to her thoughts."}
				]
			}
		"rowan_fletcher", "hollowmere_hunter":
			return {
				"speaker": "Rowan Fletcher",
				"text": "Keep to the marked paths if you can. The woods are quiet until they aren't.",
				"choices": [
					{"id": "tracks", "label": "Seen anything unusual in the woods?", "text": "Tracks crossing the old road. Some deer, some wolf. And one set I couldn't place — too heavy for a man, too deliberate for a beast."},
					{"id": "hunting", "label": "How is the hunting?", "text": "Enough game if you know where to look. The trouble is finding time to look when the roads need watching."},
					{"id": "leave", "label": "I'll take care.", "text": "Rowan gives a brief nod and checks the tree line again."}
				]
			}
		"tavern_patron", "bram_fenwick":
			return {
				"speaker": "Bram Fenwick",
				"text": "A good ale and a quiet evening. That's all a man asks — though Hollowmere seems determined to make even that difficult.",
				"choices": [
					{"id": "ironbond", "label": "What do you make of the Ironbond Company?", "text": "They take their due and call it business. Best not to ask what happens when someone can't pay."},
					{"id": "roads", "label": "How are the roads lately?", "text": "Caravans are taking the long way round. Whatever's happening north, folk with wagons aren't keen to find out."},
					{"id": "leave", "label": "Enjoy your evening.", "text": "Bram raises his mug in reply."}
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
		{"id":"night","topic":"time","roles":["any"],"hour_start":21,"hour_end":5,"lines":["You heading home?","Soon as my feet remember the route."]},
		{"id":"daily_chair","topic":"daily-life","roles":["any"],"lines":["Did you mend that chair?","I moved it where no one sits. Same result, less work."]},
		{"id":"daily_buttons","topic":"daily-life","roles":["any"],"lines":["That is a new coat.","It is an old coat with new buttons.","Then those are excellent buttons."]},
		{"id":"daily_supper","topic":"daily-life","roles":["any"],"lines":["What is for supper?","Whatever does not run away before I catch it."]},
		{"id":"daily_fiddle","topic":"daily-life","roles":["any"],"lines":["I heard Jory is learning the fiddle.","Then pray he learns it somewhere distant."]},
		{"id":"daily_market","topic":"daily-life","roles":["any"],"lines":["Market day tomorrow.","I know. My purse has already started hiding."]},
		{"id":"daily_hammer","topic":"daily-life","roles":["any"],"lines":["Seen my hammer?","Which hammer?","The good one.","Then no."]},
		{"id":"daily_cat","topic":"daily-life","roles":["any"],"lines":["I swear that cat understands every word.","Then stop telling it where you hide the cream."]},
		{"id":"weather_wind","topic":"weather","roles":["any"],"lines":["Wind changed.","You say that every time it blows the other way."]},
		{"id":"weather_spring","topic":"weather","roles":["any"],"lines":["Everything is mud again.","Means things are growing.","Mostly the mud."]},
		{"id":"weather_winter","topic":"weather","roles":["any"],"lines":["Cold enough to freeze the trough tonight.","I will bring the bucket in."]},
		{"id":"work_boss","topic":"work","roles":["any"],"lines":["Boss looking for you.","Then do not ruin a beautiful morning by telling them where I am."]},
		{"id":"work_finished","topic":"work","roles":["any"],"lines":["You finished that job?","I have finished thinking about starting it."]},
		{"id":"food_salt","topic":"food","roles":["any"],"lines":["Salt is dear again.","Everything tastes expensive these days."]},
		{"id":"food_bread","topic":"food","roles":["any"],"lines":["Save me a heel of bread.","I will save you two if you stop calling them heels."]},
		{"id":"guard_boots","topic":"guard-business","roles":["guard"],"priority":2,"lines":["Boots are wearing thin again.","Kingdom gives us spears, not feet."]},
		{"id":"guard_road","topic":"guard-business","roles":["guard"],"priority":2,"lines":["Anything on the road?","Two carts, three pilgrims, one man who looked guilty of being boring."]},
		{"id":"merchant_caravan","topic":"trade-business","roles":["merchant"],"priority":2,"lines":["Caravan late?","Caravans are never late. Prices just arrive early."]},
		{"id":"merchant_discount","topic":"trade-business","roles":["merchant"],"priority":2,"lines":["Customer asked for a discount.","Did you laugh politely?","Professionally."]},
		{"id":"farmer_fence","topic":"farm-business","roles":["farmer"],"priority":2,"lines":["Fence down again?","Same sheep, same fence, same argument."]},
		{"id":"farmer_harvest","topic":"farm-business","roles":["farmer"],"priority":2,"lines":["Fields looking alright?","Ask me after harvest. Before harvest they are all liars."]},
		{"id":"hollowmere_old_quiet","topic":"hollowmere-local","roles":["any"],"priority":3,"lines":["Hollowmere used to be quieter.","It also used to be duller. I have not decided which I preferred."]},
		{"id":"ironbond_victory","topic":"ironbond-aftermath","roles":["any"],"requires_shakedown":true,"shakedown_choice":"fight","priority":10,"lines":["You really stood up to Ironbond?","Someone had to.","Aye. Just hope they remember it next time they come calling."]},
		{"id":"ironbond_submission","topic":"ironbond-aftermath","roles":["any"],"requires_shakedown":true,"shakedown_choice":"stay_out","priority":7,"lines":["Garrick paid them, then.","What else could he do?","I know. I just wish he had a choice."]},
		{"id":"ironbond_enforcer","topic":"ironbond-aftermath","roles":["guard","merchant"],"requires_shakedown":true,"shakedown_choice":"encourage_pay","priority":8,"lines":["Heard you backed the Company.","I backed a quiet afternoon.","Quiet for whom, though?"]},
		{"id":"ironbond_uneasy","topic":"ironbond-aftermath","roles":["any"],"requires_shakedown":true,"priority":5,"lines":["Think Ironbond will come back?","Men like that always think a debt is still owed."]},
		{"id":"tavern_late","topic":"hollowmere-local","roles":["any"],"hour_start":20,"hour_end":5,"priority":3,"lines":["Last call soon?","Garrick says the last call is whenever the last fool finds the door."]},
		{"id":"morning_bread","topic":"time","roles":["any"],"hour_start":6,"hour_end":9,"priority":2,"lines":["Smells like fresh bread.","That is because someone finally remembered to bake it before noon."]},
		{"id":"late_watch","topic":"time","roles":["guard"],"hour_start":22,"hour_end":5,"priority":2,"lines":["You look half asleep.","Only half? I must be improving."]},
		{"id":"hexcrpg_ambient_daily_life_1","topic":"daily-life","roles":["any"],"priority":1,"lines":["Bread's better today.","Baker finally stopped arguing with the oven."]},
		{"id":"hexcrpg_ambient_daily_life_2","topic":"daily-life","roles":["any"],"priority":1,"lines":["I'm thinking of getting a dog.","You already complain about your neighbour's dog.","Exactly. I need representation."]},
		{"id":"hexcrpg_ambient_daily_life_3","topic":"daily-life","roles":["any"],"priority":1,"lines":["That's a new coat.","It's an old coat with new buttons.","Then those are excellent buttons."]},
		{"id":"hexcrpg_ambient_daily_life_4","topic":"daily-life","roles":["any"],"priority":1,"lines":["What's for supper?","Whatever doesn't run away before I catch it."]},
		{"id":"hexcrpg_ambient_daily_life_5","topic":"daily-life","roles":["any"],"priority":1,"lines":["You ever wonder why wells always taste of buckets?","No.","Well, now you do."]},
		{"id":"hexcrpg_ambient_daily_life_6","topic":"daily-life","roles":["any"],"priority":1,"lines":["I heard Jory's learning the fiddle.","Then pray he learns it somewhere distant."]},
		{"id":"hexcrpg_ambient_daily_life_7","topic":"daily-life","roles":["any"],"priority":1,"lines":["Morning.","Is it? I hadn't agreed to that yet."]},
		{"id":"hexcrpg_ambient_daily_life_8","topic":"daily-life","roles":["any"],"priority":1,"lines":["You cut your own hair?","What gave it away?","Nothing. Absolutely nothing."]},
		{"id":"hexcrpg_ambient_daily_life_9","topic":"daily-life","roles":["any"],"priority":1,"lines":["You smell smoke?","That's lunch.","Ah. My condolences."]},
		{"id":"hexcrpg_ambient_daily_life_10","topic":"daily-life","roles":["any"],"priority":1,"lines":["Got a spare needle?","Had one yesterday.","Useful information yesterday."]},
		{"id":"hexcrpg_ambient_daily_life_11","topic":"daily-life","roles":["any"],"priority":1,"lines":["Your boy still wants to be an adventurer?","Until I ask him to carry firewood. Then his knees go bad."]},
		{"id":"hexcrpg_ambient_daily_life_12","topic":"daily-life","roles":["any"],"priority":1,"lines":["I found a silver penny under the bed.","Yours?","It is now."]},
		{"id":"hexcrpg_ambient_daily_life_13","topic":"daily-life","roles":["any"],"priority":1,"lines":["Someone's been stealing apples from my tree.","You don't own an apple tree.","That explains the difficulty proving it."]},
		{"id":"hexcrpg_ambient_daily_life_14","topic":"daily-life","roles":["any"],"priority":1,"lines":["I could sleep for a week.","You'd wake up hungry on the second day."]},
		{"id":"hexcrpg_ambient_daily_life_15","topic":"daily-life","roles":["any"],"priority":1,"lines":["That stew smells good.","Give it time."]},
		{"id":"hexcrpg_ambient_weather_16","topic":"weather","roles":["any"],"priority":1,"lines":["Fine day for once.","Don't say it too loudly. Weather takes criticism personally."]},
		{"id":"hexcrpg_ambient_work_17","topic":"work","roles":["any"],"priority":1,"lines":["How's work?","Still there every morning, despite my best efforts."]},
		{"id":"hexcrpg_ambient_work_18","topic":"work","roles":["any"],"priority":1,"lines":["Boss looking for you.","Then don't ruin a beautiful morning by telling them where I am."]},
		{"id":"hexcrpg_ambient_work_19","topic":"work","roles":["any"],"priority":1,"lines":["Hands are killing me.","Means you used them. Very fashionable among workers."]},
		{"id":"hexcrpg_ambient_food_20","topic":"food","roles":["any"],"priority":1,"lines":["I miss fresh berries.","You miss stealing fresh berries."]},
		{"id":"hexcrpg_ambient_food_21","topic":"food","roles":["any"],"priority":1,"lines":["Salt's dear again.","Everything tastes expensive these days."]},
		{"id":"hexcrpg_ambient_food_22","topic":"food","roles":["any"],"priority":1,"lines":["Save me a heel of bread.","I'll save you two if you stop calling them heels."]},
		{"id":"hexcrpg_ambient_guard_business_23","topic":"guard-business","roles":["guard"],"priority":2,"lines":["You checking every wagon?","Only the ones whose drivers tell me not to."]},
		{"id":"hexcrpg_ambient_mine_business_24","topic":"mine-business","roles":["miner"],"priority":2,"lines":["How's the seam?","Hard rock, decent ore, bad language."]},
		{"id":"hexcrpg_ambient_mine_business_25","topic":"mine-business","roles":["miner"],"priority":2,"lines":["Hear that ringing below?","Aye. Means someone's earning twice what we're being paid."]},
		{"id":"hexcrpg_ambient_mine_business_26","topic":"mine-business","roles":["miner"],"priority":2,"lines":["Need a new pick-head.","Get in line. The mine eats iron faster than miners eat stew."]},
		{"id":"hexcrpg_ambient_mine_business_27","topic":"mine-business","roles":["miner"],"priority":2,"lines":["Dust in my teeth again.","Luxury. Means you've still got teeth."]},
		{"id":"hexcrpg_ambient_trade_business_28","topic":"trade-business","roles":["merchant"],"priority":2,"lines":["You taking copper today?","At yesterday's price, certainly not."]},
		{"id":"hexcrpg_ambient_trade_business_29","topic":"trade-business","roles":["merchant"],"priority":2,"lines":["Road tolls went up again?","No. The rumour did. Give the tollkeeper an hour."]},
		{"id":"hexcrpg_ambient_faith_30","topic":"faith","roles":["clergy"],"priority":2,"lines":["Chapel busy?","People remember the gods whenever something starts rattling at night."]},
		{"id":"hexcrpg_ambient_faith_31","topic":"faith","roles":["clergy"],"priority":2,"lines":["You lighting a candle?","For patience.","Working?","Ask me less often."]},
		{"id":"hexcrpg_ambient_faith_32","topic":"faith","roles":["clergy"],"priority":2,"lines":["Do prayers count if you fall asleep halfway through?","Depends which half."]},
		{"id":"hexcrpg_ambient_farm_business_33","topic":"farm-business","roles":["farmer"],"priority":2,"lines":["Fields looking alright?","Ask me after harvest. Before harvest they're all liars."]},
		{"id":"hexcrpg_ambient_farm_business_34","topic":"farm-business","roles":["farmer"],"priority":2,"lines":["Your mare still kicking?","Only people she dislikes.","She kicked me.","I know."]},
		{"id":"hexcrpg_ambient_hollowmere_local_35","topic":"hollowmere-local","roles":["any"],"priority":3,"lines":["Hollowmere used to be quieter.","It also used to be duller. I haven't decided which I preferred."]},
		{"id":"hexcrpg_ambient_millbrook_local_36","topic":"millbrook-local","roles":["any"],"priority":3,"lines":["Another wagon north this morning.","Aye. More lamp oil than food. Tells you where the coin's going."]},
		{"id":"hexcrpg_ambient_millbrook_local_37","topic":"millbrook-local","roles":["any"],"priority":3,"lines":["Bell at the chapel sticks again.","Only on holy days. Very devout mechanism."]},
		{"id":"hexcrpg_ambient_millbrook_local_38","topic":"millbrook-local","roles":["any"],"priority":3,"lines":["Petra counted those crates twice.","Petra counts everything twice. That's why things arrive."]},
		{"id":"hexcrpg_ambient_millbrook_local_39","topic":"millbrook-local","roles":["any"],"priority":3,"lines":["Forest was loud last night.","Forest is always loud.","Not like that."]},
		{"id":"hexcrpg_ambient_emberlode_local_40","topic":"emberlode-local","roles":["any"],"priority":3,"lines":["Crooked Pick after shift?","Only if you promise not to order the thing they call stew."]},
		{"id":"hexcrpg_ambient_emberlode_local_41","topic":"emberlode-local","roles":["any"],"priority":3,"lines":["Assay office says the east face is richer.","Assay office doesn't have to swing the pick."]},
		{"id":"hexcrpg_ambient_emberlode_local_42","topic":"emberlode-local","roles":["any"],"priority":3,"lines":["Those old supports below still bother me.","They're straighter than anything we build now. That's the bothering part."]},
		{"id":"hexcrpg_ambient_emberlode_local_43","topic":"emberlode-local","roles":["any"],"priority":3,"lines":["Hear they found glassy stone in the deep cut.","Hear lots of things underground. Most of them I prefer not to meet."]},
		{"id":"hexcrpg_ambient_reddale_local_44","topic":"reddale-local","roles":["any"],"priority":3,"lines":["Watch doubled the gate walk again.","Makes the gate feel very important."]},
		{"id":"hexcrpg_ambient_reddale_local_45","topic":"reddale-local","roles":["any"],"priority":3,"lines":["Inn's full of road dust and merchants.","So, merchants."]},
		{"id":"hexcrpg_ambient_reddale_local_46","topic":"reddale-local","roles":["any"],"priority":3,"lines":["Reeve's clerk wants forms for everything now.","Do we need a form to complain?","Two copies."]},
		{"id":"hexcrpg_ambient_silverhart_local_47","topic":"silverhart-local","roles":["any"],"priority":3,"lines":["Capital never sleeps, does it?","It sleeps. It just charges rent while doing it."]},
		{"id":"hexcrpg_ambient_silverhart_local_48","topic":"silverhart-local","roles":["any"],"priority":3,"lines":["Another procession on the avenue.","Was wondering why everyone suddenly remembered how to bow."]},
		{"id":"hexcrpg_ambient_silverhart_local_49","topic":"silverhart-local","roles":["any"],"priority":3,"lines":["Court's arguing again.","Good. Means they're too busy to notice us."]},
		{"id":"hexcrpg_ambient_silverhart_local_50","topic":"silverhart-local","roles":["any"],"priority":3,"lines":["Market bells rang early.","Prices heard them and ran ahead."]}
	]
