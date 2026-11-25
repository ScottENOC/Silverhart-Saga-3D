class_name SourceCampaignNpcDialogue
extends RefCounted
## Source-authored direct NPC dialogue that can be used by the 3D campaign.
## This is content only: it does not start quests or perform unsupported shop,
## inventory, recruitment, or faction actions. Those remain in their services.

static func greeting(npc_id: String, npc_name: String, role: String = "villager", context: Dictionary = {}) -> Dictionary:
	match npc_id:
		"garrick_holt":
			return {
				"speaker": "Garrick Holt",
				"text": "Welcome to the Hollow Tankard! Sit, drink, rest a while.",
				"prefer_source": false,
				"choices": [
					{"id":"source_garrick_news","label":"What's the word around here?","text":"Quiet, lately. Same faces, same ale. I'll take it — quiet's been hard-earned around here."},
					{"id":"source_garrick_wary","label":"How are things in the village?","text":"The roads have been rough lately. Keep the door barred after dark, if you can."}
				]
			}
		"mira_ashbrook":
			var mira_news := "My cousin rode with the Silverhart levy up to the borderlands, fighting off orc raiders. Last letter said the raids have gotten worse — bigger warbands than the old stories tell. I try not to think on it too much."
			if bool(context.get("goblin_scout_note_read", false)):
				mira_news = "My cousin rode with the Silverhart levy up to the borderlands. The raids have grown more organised — and after what you found near Hollowmere, I wonder whether all these troubles are connected."
			return {
				"speaker":"Mira Ashbrook",
				"prefer_source":false,
				"choices":[
					{"id":"source_mira_cousin","label":"Tell me about your cousin in the levy.","text":mira_news},
					{"id":"source_mira_worry","label":"Does the news worry you?","text":"I try not to think on it too much. There's little use frightening people with rumours, but pretending nothing is happening won't make it go away."}
				]
			}
		"oskar_vinn":
			return {
				"speaker":"Oskar Vinn",
				"prefer_source":false,
				"choices":[
					{"id":"source_oskar_levies","label":"What have you heard about the border?","text":"The levies keep marching north. Orc raiders on the border, apparently — worse than usual this year. Half tempted to go make a name for myself up there instead of sparring with tavern drunks."},
					{"id":"source_oskar_spar","label":"Care to spar?","text":"Ha! Thought you'd never ask. Don't hold back on my account.","available":false,"unavailable_reason":"The duel encounter is not connected to the 3D combat interface yet."}
				]
			}
		"wick_hallow":
			return {
				"speaker":"Wick Hallow",
				"prefer_source":false,
				"choices":[
					{"id":"source_wick_stock","label":"What sort of stock do you keep?","text":"Welcome to Hallow's Goods. Soldier-grade gear, fair prices — what's left of my stock, anyway."},
					{"id":"source_wick_delivery","label":"Heard you've had some trouble with a delivery.","text":"A goblin scout snatched a delivery of mine not far from here, south and west of the shop. Little thing, shouldn't be hard to catch — but I can't leave the counter to do it.","available":false,"unavailable_reason":"The stolen-delivery quest has not yet been connected to the 3D campaign."}
				]
			}
		"hendra_wells":
			return {
				"speaker":"Hendra Wells",
				"text":"My boy Tam's always off exploring — never listens. But it's been since yesterday, and he always comes home by dark. He was headed out past the crossroads, west along the old road.",
				"prefer_source":true,
				"choices":[
					{"id":"source_hendra_look","label":"I'll go look for him.","text":"Please, if you find anything out there...","available":false,"unavailable_reason":"The Missing Boy quest and Tam's encounter are not yet ported to the 3D campaign."},
					{"id":"source_hendra_reassure","label":"I'm sure he's fine.","text":"Hendra tries to smile, but keeps glancing towards the road."}
				]
			}
		"yvette_marlow":
			return {
				"speaker":"Yvette Marlow",
				"text":"Oh — sorry, didn't mean to stare. My boy Tomas went off with the border levy three months back, fighting orc raiders up past Aldervale.",
				"prefer_source":true,
				"choices":[
					{"id":"source_yvette_letter","label":"Have you heard from him?","text":"A letter, once, back in Brightsun. Said the raids were getting worse — more of them, better organised than the raiding parties used to be. Nothing since. I try to tell myself the roads are just slow this time of year."},
					{"id":"source_yvette_sorry","label":"I'm sorry to hear that.","text":"Thank you. You learn to keep hoping, even when the post rider brings nothing."}
				]
			}
		"marta_wynfield":
			var player_race := String(context.get("player_race", "human")).to_lower()
			if player_race == "goblin" or player_race == "orc":
				return {
					"speaker":"Elder Marta Wynfield",
					"text":"A greenskin, bold as you like, walking Hollowmere's own streets? Give me one reason the Watch shouldn't drag you out right now.",
					"prefer_source":true,
					"choices":[
						{"id":"source_marta_prove","label":"I'll bring word of my own chief's plans, if that buys me anything.","text":"Then bring me something worth hearing. Until you do, do not mistake my patience for trust.","available":false,"unavailable_reason":"The Prove Your Worth diplomacy quest is not yet ported."},
						{"id":"source_marta_leave","label":"I mean Hollowmere no harm.","text":"That remains to be seen. Keep your hands visible and your promises plain."}
					]
				}
			var standing := float(context.get("marta_standing", 0.0))
			var opening := "Welcome, traveler. Hollowmere's a small place, but an honest one."
			if bool(context.get("shakedown_resolved", false)):
				if standing >= 15.0:
					opening = "Word of what you did at the Tankard reached me. Hollowmere doesn't forget a favour like that."
				elif standing <= -5.0:
					opening = "I heard about the Tankard. Garrick's a proud man — I imagine that stung him more than you know."
				else:
					opening = "I heard the Ironbond men were in the village again. Nothing's changed there, I'm afraid."
			return {
				"speaker":"Elder Marta Wynfield",
				"text":opening,
				"prefer_source":true,
				"choices":[
					{"id":"source_marta_locket","label":"Have you lost something?","text":"My mother's locket went missing years ago, somewhere near the old chapel. Silly to still hope, but if you ever spot it...","available":false,"unavailable_reason":"The Missing Locket quest is not yet ported."},
					{"id":"source_marta_goblins","label":"What troubles you most?","text":"West of here, past the crossroads, a goblin tribe has made camp. They've traded a little and kept their distance so far — but hungry folk can become desperate folk."}
				]
			}
		"rowan_fletcher", "hollowmere_hunter":
			var wary := float(context.get("hollowmere_security", 50.0)) < 30.0
			var hunting_line := "Good hunting country, this — plenty of deer, the odd wild boar if you're careful. Yours if you can track it."
			if wary:
				hunting_line = "Careful out here — Hollowmere's had a rough stretch, and it shows in the wildlife too. Fewer deer, more of what hunts them."
			return {
				"speaker":npc_name if not npc_name.is_empty() else "Rowan Fletcher",
				"text":hunting_line,
				"prefer_source":true,
				"choices":[
					{"id":"source_hunter_sell","label":"I've got game meat and hide to sell.","text":"Bring me meat or hide from something you've hunted. I pay a fair price for a clean haul.","available":false,"unavailable_reason":"The hunter's buy-and-sell inventory action is not yet connected to the 3D economy."},
					{"id":"source_hunter_news","label":"Any word on the roads?","text":"Nothing worth repeating. Tracks are thin lately — good for me, I suppose."},
					{"id":"source_hunter_leave","label":"Good hunting.","text":"Keep your eyes open and your wind in your face."}
				]
			}
		"hollowmere_beggar":
			return {"speaker":npc_name,"text":"Spare a coin? Times are hard in Hollowmere just now. Wasn't always like this.","prefer_source":true,"choices":[{"id":"source_beggar_give","label":"Give 2 gold.","text":"The beggar thanks you quietly.","available":false,"unavailable_reason":"The small-gift gold action is not yet connected."},{"id":"source_beggar_decline","label":"Sorry, nothing to spare.","text":"The beggar nods and looks away."}]}
		"hollowmere_peddler":
			return {"speaker":npc_name,"text":"Business is good these days — Hollowmere's doing well for itself. Care to see my wares? Just trinkets, nothing you can't live without, but pretty ones.","prefer_source":true,"choices":[{"id":"source_peddler_leave","label":"Maybe another time.","text":"The peddler turns back to their wares."}]}
	return {}


static func merge_with_existing(existing: Dictionary, source: Dictionary) -> Dictionary:
	if source.is_empty():
		return existing.duplicate(true)
	var result := existing.duplicate(true)
	if bool(source.get("prefer_source", false)):
		result = source.duplicate(true)
		var existing_text := String(existing.get("text", ""))
		if not existing_text.is_empty() and existing_text != String(source.get("text", "")) and existing_text != "The villager gives you a polite nod.":
			var choices: Array = result.get("choices", []).duplicate(true)
			choices.append({"id":"silverhart_existing_greeting","label":"Anything else?","text":existing_text})
			result["choices"] = choices
		return result
	var merged_choices: Array = result.get("choices", []).duplicate(true)
	var existing_ids: Dictionary = {}
	for choice_value in merged_choices:
		var choice: Dictionary = choice_value
		existing_ids[String(choice.get("id", ""))] = true
	for choice_value in source.get("choices", []):
		var choice: Dictionary = choice_value
		var choice_id := String(choice.get("id", ""))
		if not existing_ids.has(choice_id):
			merged_choices.append(choice.duplicate(true))
			existing_ids[choice_id] = true
	result["choices"] = merged_choices
	return result


static func generic_greeting(npc_id: String, npc_name: String, role: String = "villager") -> Dictionary:
	var normalized_role := role.to_lower()
	var lines: Array[Dictionary] = []
	if normalized_role.contains("guard") or normalized_role.contains("watch") or normalized_role.contains("soldier"):
		lines = [
			{"text":"Keep to the main road after dark. I don't fancy explaining another missing traveller to the reeve.","reply":"The roads have been quiet today. Let's keep them that way."},
			{"text":"Nothing to report. Which is generally how I prefer a watch to go.","reply":"You say that as though trouble listens."},
			{"text":"You travelling through, or looking for someone? Either way, don't block the gate.","reply":"I'll keep moving. No need to make a morning of it."},
			{"text":"My boots are wearing through. The quartermaster says the kingdom issues spears, not feet.","reply":"At least the spear won't give you blisters."}
		]
	elif normalized_role.contains("merchant") or normalized_role.contains("trader") or normalized_role.contains("shop"):
		lines = [
			{"text":"If it fits in a pack and lasts longer than a day, someone will buy it.","reply":"And if it doesn't sell?","reply_text":"Then I learn to like it myself."},
			{"text":"Caravans are never late. Prices just arrive early.","reply":"That sounds suspiciously convenient for you."},
			{"text":"Have a look if you like. Looking is free; touching is how things get expensive.","reply":"I'll remember that."},
			{"text":"The road tolls haven't gone up. The rumour has, though.","reply":"Rumours travel faster than wagons."}
		]
	elif normalized_role.contains("farm") or normalized_role.contains("shepherd") or normalized_role.contains("herd"):
		lines = [
			{"text":"Ask me how the fields look after harvest. Before then, they're all liars.","reply":"I'll take your word for it."},
			{"text":"Same sheep, same fence, same argument. One day the sheep will win.","reply":"I'd put my money on the fence."},
			{"text":"The animals know when rain is coming. They also know when I'm carrying feed.","reply":"A useful skill, if you can tell the difference."},
			{"text":"Lost another hour mending a gate. The gate's winning this year.","reply":"At least it stays where you put it."}
		]
	elif normalized_role.contains("miner") or normalized_role.contains("smith") or normalized_role.contains("craft"):
		lines = [
			{"text":"Hard work, decent materials, and someone always asking if it can be done cheaper.","reply":"Can it?","reply_text":"Not if you want it done twice."},
			{"text":"The rock's stubborn today. So am I.","reply":"Sounds like a fair contest."},
			{"text":"I can hear the hammer in my sleep. Sometimes I think the hammer can hear me.","reply":"Best not start answering it."}
		]
	elif normalized_role.contains("clergy") or normalized_role.contains("priest") or normalized_role.contains("healer"):
		lines = [
			{"text":"People remember the gods whenever something starts rattling at night.","reply":"And do the gods answer?","reply_text":"Sometimes. Usually after people have tried fixing the rattling themselves."},
			{"text":"I lit a candle for patience this morning. It has not helped yet.","reply":"Perhaps you need a larger candle."}
		]
	else:
		lines = [
			{"text":"You look like you've come a long way. The road's been hard on everyone lately.","reply":"Is there trouble nearby?","reply_text":"There's always trouble somewhere. Best not go looking for all of it."},
			{"text":"Long day? Mine became a long day shortly after breakfast.","reply":"What happened?","reply_text":"Breakfast was late."},
			{"text":"Market day tomorrow. My purse has already started hiding.","reply":"Can you blame it?"},
			{"text":"Rain before dusk, I reckon. The enormous black cloud is a reliable sign.","reply":"I'll take your word for it."},
			{"text":"I lost a boot this morning. Still haven't worked out how.","reply":"How do you lose one boot?","reply_text":"If I knew that, I'd know where it was."},
			{"text":"The village used to be quieter. It also used to be duller. I haven't decided which I preferred.","reply":"Perhaps both have their merits."}
		]
	var index := int(abs(npc_id.hash())) % lines.size()
	var selected: Dictionary = lines[index]
	var reply_text := String(selected.get("reply_text", selected.get("reply", "They give you a small nod and return to their work.")))
	return {
		"speaker":npc_name,
		"text":String(selected.get("text", "They have little to say.")),
		"choices":[{"id":"generic_reply","label":"Anything else happening?","text":reply_text},{"id":"generic_leave","label":"Good day.","text":"They return to what they were doing."}]
	}
