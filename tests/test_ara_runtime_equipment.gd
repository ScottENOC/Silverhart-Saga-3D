extends SceneTree

const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const FACTORY_SCRIPT = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const BODY_PATH := "res://art/characters/ara_runtime/ara_person_body_anatomy.glb"
const MALE_BODY_PATH := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const GARMENT_ROOT := "res://art/characters/ara_runtime/garments/"
const REQUIRED_GARMENTS := [
    "lace_briefs", "fishnet_briefs",
    "lace_pants", "fishnet_pants",
    "lace_shirt", "fishnet_shirt",
    "halter_bra_lace", "halter_bra_fishnet",
    "leather_armor"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(ResourceLoader.exists(BODY_PATH), "Missing female Ara base body")
    assert(ResourceLoader.exists(MALE_BODY_PATH), "Missing male Ara base body")

    var missing: Array[String] = []
    for garment_id in REQUIRED_GARMENTS:
        var path: String = GARMENT_ROOT + "female_" + garment_id + ".glb"
        if not ResourceLoader.exists(path):
            missing.append(path)
    if not missing.is_empty():
        push_error("Selected standalone Ara garment assets are missing: %s" % ", ".join(missing))
        quit(1)
        return

    var actor := ACTOR_SCRIPT.new() as AraCharacterActor
    root.add_child(actor)
    assert(actor.configure(BODY_PATH), "Could not configure female Ara base body")
    var braid_path := "res://art/characters/ara_runtime/hair/female_braid01.glb"
    assert(ResourceLoader.exists(braid_path), "Missing Ara female braid hairstyle")
    assert(actor.set_hairstyle(braid_path), "Could not bind Ara braid to the shared female body")
    assert(not actor.hair_instances.is_empty(), "Ara braid attached no skinned meshes")
    actor.apply_player_profile({"body_variant": "female"})

    var equipment: Dictionary = {}
    for garment_id in REQUIRED_GARMENTS:
        if garment_id == "leather_armor":
            equipment["armour"] = {"id": "light_armor"}
        else:
            equipment["garment_" + garment_id] = {
                "id": garment_id,
                "garment_visual": garment_id
            }
    actor.apply_equipment_visuals(equipment)
    await process_frame

    var attachments: Dictionary = actor.get("garment_attachments")
    for garment_id in REQUIRED_GARMENTS:
        assert(attachments.has(garment_id), "Selected garment did not attach: %s" % garment_id)
        var meshes: Array = attachments[garment_id]
        assert(not meshes.is_empty(), "Garment contains no mesh instances: %s" % garment_id)
        for mesh in meshes:
            assert(is_instance_valid(mesh) and mesh.visible, "Equipped garment is not visible: %s" % garment_id)

    # Legacy inventory names intentionally resolve to the approved lace defaults.
    actor.apply_equipment_visuals({
        "underTop": {"id": "bra", "garment_visual": "bra"},
        "underBottom": {"id": "briefs", "garment_visual": "briefs"}
    })
    await process_frame
    assert(attachments.has("halter_bra_lace"), "Legacy bra alias did not resolve to lace halter bra")
    assert(attachments.has("lace_briefs"), "Legacy briefs alias did not resolve to lace briefs")
    for garment_id in attachments:
        for mesh in attachments[garment_id]:
            var expected_visible: bool = garment_id in ["halter_bra_lace", "lace_briefs"]
            assert(mesh.visible == expected_visible, "Garment visibility did not follow equipment state: %s" % garment_id)

    var settlement_npc := {
        "id": "test_settlement_female",
        "name": "Test Settler",
        "body_variant": "female",
        "appearance": {"hair_style": "short02", "hair_colour": "Dark brown"},
        "visual_equipment": {
            "shirt": {"id": "lace_shirt", "garment_visual": "lace_shirt"}
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
    assert(settlement_attachments.has("lace_shirt"), "Settlement NPC did not receive its equipped shirt")
    assert(settlement_attachments["lace_shirt"][0].visible, "Settlement NPC shirt is not visible")

    var male_actor := ACTOR_SCRIPT.new() as AraCharacterActor
    root.add_child(male_actor)
    assert(male_actor.configure(MALE_BODY_PATH), "Could not configure male Ara base body")
    male_actor.apply_player_profile({"body_variant": "male"})
    male_actor.apply_equipment_visuals({"shirt": {"id": "lace_shirt", "garment_visual": "lace_shirt"}})
    assert((male_actor.get("garment_attachments") as Dictionary).is_empty(), "Female garment asset was incorrectly attached to male body")

    actor.apply_equipment_visuals({
        "weapon": {"id": "sword"},
        "offhand": {"id": "wooden_shield"}
    })
    await process_frame
    var props: Dictionary = actor.get("equipment_attachments")
    assert(props.has("weapon"), "Sword did not attach to WeaponR")
    assert(props.has("offhand"), "Shield did not attach to WeaponL")

    print("ARA_RUNTIME_EQUIPMENT_TEST: PASS (female body, selected standalone garments, armour, sword and shield)")
    actor.queue_free()
    male_actor.queue_free()
    settlement_actor.queue_free()
    quit(0)
