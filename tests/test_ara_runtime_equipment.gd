extends SceneTree

const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const FACTORY_SCRIPT = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const BODY_PATH := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_BODY_PATH := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const GARMENT_ROOT := "res://art/characters/ara_runtime/garments/"
const REQUIRED_GARMENTS := [
    "bra", "briefs", "fatigue_shirt", "fatigue_pants", "combat_boots",
    "tunic", "long_tunic", "trousers", "wrapper_long", "wrapper_knee",
    "uniform_shirt", "tattered_shirt", "sandals", "leather_armor"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(ResourceLoader.exists(BODY_PATH), "Missing female Ara base body")
    assert(ResourceLoader.exists(MALE_BODY_PATH), "Missing male Ara base body")

    var missing: Array[String] = []
    for garment_id in REQUIRED_GARMENTS:
        var path := GARMENT_ROOT + "female_" + garment_id + ".glb"
        if not ResourceLoader.exists(path):
            missing.append(path)
    if not missing.is_empty():
        push_error("Separate Ara runtime garment assets are missing: %s" % ", ".join(missing))
        quit(1)
        return

    var actor := ACTOR_SCRIPT.new() as AraCharacterActor
    root.add_child(actor)
    assert(actor.configure(BODY_PATH), "Could not configure female Ara base body")
    actor.apply_player_profile({"body_variant": "female"})
    actor.apply_equipment_visuals({
        "underTop": {"id": "bra", "garment_visual": "bra"},
        "underBottom": {"id": "briefs", "garment_visual": "briefs"},
        "shirt": {"id": "tunic", "garment_visual": "tunic"},
        "pants": {"id": "trousers", "garment_visual": "trousers"},
        "shoes": {"id": "sandals", "garment_visual": "sandals"},
        "armour": {"id": "light_armor"}
    })
    await process_frame

    var attachments: Dictionary = actor.get("garment_attachments")
    for garment_id in ["bra", "briefs", "tunic", "trousers", "sandals", "leather_armor"]:
        assert(attachments.has(garment_id), "Equipped garment did not attach: %s" % garment_id)
        var meshes: Array = attachments[garment_id]
        assert(not meshes.is_empty(), "Garment contains no mesh instances: %s" % garment_id)
        for mesh in meshes:
            assert(is_instance_valid(mesh) and mesh.visible, "Equipped garment is not visible: %s" % garment_id)

    actor.apply_equipment_visuals({})
    await process_frame
    for garment_id in attachments:
        for mesh in attachments[garment_id]:
            assert(not mesh.visible, "Unequipped garment remains visible: %s" % garment_id)

    var settlement_npc := {
        "id": "test_settlement_female",
        "name": "Test Settler",
        "body_variant": "female",
        "appearance": {"hair_style": "short02", "hair_colour": "Dark brown"},
        "visual_equipment": {
            "shirt": {"id": "tunic", "garment_visual": "tunic"}
        }
    }
    var settlement_actor := FACTORY_SCRIPT.create_settlement_actor(settlement_npc, Vector3.ZERO)
    assert(settlement_actor != null, "Shared factory did not create a settlement NPC")
    root.add_child(settlement_actor)
    assert(settlement_actor.is_in_group("campaign2_npc"), "Settlement actor lost its NPC group")
    var settlement_model := settlement_actor.get_node_or_null("CharacterModel") as AraCharacterActor
    assert(settlement_model != null, "Settlement actor did not use the shared Ara renderer")
    await process_frame
    var settlement_attachments: Dictionary = settlement_model.get("garment_attachments")
    assert(settlement_attachments.has("tunic"), "Settlement NPC did not receive its equipped tunic")
    assert(settlement_attachments["tunic"][0].visible, "Settlement NPC tunic is not visible")

    var male_actor := ACTOR_SCRIPT.new() as AraCharacterActor
    root.add_child(male_actor)
    assert(male_actor.configure(MALE_BODY_PATH), "Could not configure male Ara base body")
    male_actor.apply_player_profile({"body_variant": "male"})
    male_actor.apply_equipment_visuals({"shirt": {"id": "tunic", "garment_visual": "tunic"}})
    assert((male_actor.get("garment_attachments") as Dictionary).is_empty(), "Female garment asset was incorrectly attached to male body")

    actor.apply_equipment_visuals({
        "weapon": {"id": "sword"},
        "offhand": {"id": "wooden_shield"}
    })
    await process_frame
    var props: Dictionary = actor.get("equipment_attachments")
    assert(props.has("weapon"), "Sword did not attach to WeaponR")
    assert(props.has("offhand"), "Shield did not attach to WeaponL")

    print("ARA_RUNTIME_EQUIPMENT_TEST: PASS (female body, separate garments, armour, sword and shield)")
    actor.queue_free()
    male_actor.queue_free()
    settlement_actor.queue_free()
    quit(0)
