class_name SpellVfxController
extends Node3D
## Presentation-only spell effects. Simulation results remain authoritative;
## this node listens to successful spell events and never changes game state.

const PROJECTILE_SPEED := 18.0
const DEFAULT_DURATION := 0.9

func play_spell(
    spell_id: String,
    caster: Node3D,
    target: Node3D,
    target_position: Vector3,
    payload: Dictionary = {},
    affected_actors: Array[Node3D] = []
) -> void:
    var origin := caster.global_position + Vector3.UP * 1.15 if caster != null else target_position + Vector3.UP * 1.0
    var impact := target.global_position + Vector3.UP * 0.8 if target != null else target_position + Vector3.UP * 0.55
    var colour := _spell_colour(spell_id)

    match spell_id:
        "firebolt":
            _play_projectile(origin, impact, Color(1.0, 0.29, 0.055), 0.34, 0.52)
        "heal":
            _play_heal(impact)
        "divine_protection":
            _play_shield(impact, Color(0.42, 0.75, 1.0), 1.1)
        "divine_strength":
            _play_aura(impact, Color(1.0, 0.72, 0.24), 1.15, 1.0)
            _play_ring(impact, Color(1.0, 0.88, 0.48), 0.2, 1.4, 0.9)
        "curse":
            _play_aura(impact, Color(0.42, 0.16, 0.62), 1.05, 1.0)
            _play_ring(impact, Color(0.68, 0.34, 0.82), 0.15, 1.25, 0.8)
        "summon_animal":
            _play_summon_circle(target_position, Color(0.68, 0.78, 0.94))
        "counterspell":
            _play_counterspell(origin, impact)
        "entangle":
            _play_entangle(target_position, affected_actors)
        "wild_fury":
            _play_aura(impact, Color(0.92, 0.19, 0.075), 1.2, 1.0)
            _play_ring(impact, Color(1.0, 0.42, 0.12), 0.15, 1.0, 0.65)
        "calm_animal":
            _play_aura(impact, Color(0.45, 0.82, 0.48), 1.0, 1.1)
            _play_ring(impact, Color(0.70, 0.92, 0.62), 0.2, 1.1, 0.8)
        "disguise_self":
            _play_shimmer(impact)
        "feather_fall":
            _play_feather_fall(impact)
        _:
            _play_aura(impact, colour, 0.8, DEFAULT_DURATION)

    # Area spells give each affected character a small, readable confirmation
    # in addition to the central area effect.
    if spell_id in ["firebolt", "heal", "entangle"]:
        for actor in affected_actors:
            if actor == null or actor == target:
                continue
            var actor_position := actor.global_position + Vector3.UP * 0.55
            _play_impact(actor_position, colour, 0.45, 0.34)


func _spell_colour(spell_id: String) -> Color:
    match spell_id:
        "heal":
            return Color(0.28, 0.68, 1.0)
        "divine_strength":
            return Color(1.0, 0.72, 0.24)
        "curse":
            return Color(0.53, 0.31, 0.72)
        "entangle", "calm_animal":
            return Color(0.36, 0.78, 0.40)
        "divine_protection", "feather_fall":
            return Color(0.48, 0.82, 1.0)
        "wild_fury":
            return Color(0.94, 0.22, 0.09)
        _:
            return Color(1.0, 0.42, 0.12)


func _make_material(colour: Color, energy: float = 1.5, alpha: float = 1.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
    material.emission_enabled = true
    material.emission = colour
    material.emission_energy_multiplier = energy
    if alpha < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material


func _add_sphere(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance


func _add_ring(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius * 0.84
    mesh.outer_radius = radius
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance


func _play_projectile(origin: Vector3, destination: Vector3, colour: Color, duration: float, impact_radius: float) -> void:
    var projectile := Node3D.new()
    projectile.name = "SpellProjectile"
    projectile.global_position = origin
    add_child(projectile)
    _add_sphere(projectile, 0.23, _make_material(colour, 3.5))
    _add_sphere(projectile, 0.37, _make_material(colour.lightened(0.2), 1.8, 0.22))
    var light := OmniLight3D.new()
    light.light_color = colour
    light.light_energy = 1.8
    light.omni_range = 3.8
    projectile.add_child(light)

    var travel := create_tween()
    travel.set_trans(Tween.TRANS_CUBIC)
    travel.set_ease(Tween.EASE_IN)
    travel.tween_property(projectile, "global_position", destination, duration)
    travel.tween_callback(func():
        projectile.queue_free()
        _play_impact(destination, colour, impact_radius, 0.48)
    )


func _play_breath(origin: Vector3, destination: Vector3) -> void:
    # A chain of overlapping flame cores reads as a short cone of breath
    # rather than a single oversized projectile.
    var direction := destination - origin
    var distance := direction.length()
    if distance < 0.1:
        _play_impact(destination, Color(1.0, 0.30, 0.055), 1.6, 0.55)
        return
    var segments := 6
    for index in range(segments):
        var fraction := float(index + 1) / float(segments + 1)
        var bead_position := origin.lerp(destination, fraction)
        var bead := Node3D.new()
        bead.name = "DragonBreathFlame"
        bead.global_position = bead_position
        add_child(bead)
        var radius := lerpf(0.12, 0.42, fraction)
        _add_sphere(bead, radius, _make_material(Color(1.0, 0.27 + fraction * 0.18, 0.035), 2.8, 0.82))
        var tween := create_tween()
        tween.tween_interval(0.12 + fraction * 0.12)
        tween.tween_property(bead, "scale", Vector3.ONE * 1.8, 0.28)
        tween.tween_callback(bead.queue_free)
    _play_impact(destination, Color(1.0, 0.31, 0.045), 1.9, 0.62)


func _play_heal(position: Vector3) -> void:
    _play_aura(position, Color(0.24, 0.64, 1.0), 1.2, 1.0)
    _play_ring(position, Color(0.54, 0.84, 1.0), 0.25, 1.45, 0.95)
    var light := OmniLight3D.new()
    light.light_color = Color(0.32, 0.68, 1.0)
    light.light_energy = 2.0
    light.omni_range = 4.5
    light.global_position = position
    add_child(light)
    var tween := create_tween()
    tween.tween_property(light, "light_energy", 0.0, 0.9)
    tween.tween_callback(light.queue_free)


func _play_aura(position: Vector3, colour: Color, radius: float, duration: float) -> void:
    var aura := Node3D.new()
    aura.name = "SpellAura"
    aura.global_position = position
    add_child(aura)
    var core := _add_sphere(aura, radius * 0.72, _make_material(colour, 1.5, 0.18))
    core.position.y = 0.25
    var ring := _add_ring(aura, radius, _make_material(colour.lightened(0.25), 2.0, 0.85))
    ring.position.y = -0.35
    aura.scale = Vector3(0.45, 0.45, 0.45)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(aura, "scale", Vector3.ONE, duration * 0.35)
    tween.tween_interval(duration * 0.25)
    tween.tween_property(aura, "scale", Vector3.ONE * 1.35, duration * 0.4)
    tween.tween_callback(aura.queue_free)


func _play_ring(position: Vector3, colour: Color, start_radius: float, end_radius: float, duration: float) -> void:
    var ring_root := Node3D.new()
    ring_root.global_position = position
    add_child(ring_root)
    var ring := _add_ring(ring_root, 1.0, _make_material(colour, 2.0, 0.9))
    ring.scale = Vector3.ONE * start_radius
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(ring, "scale", Vector3.ONE * end_radius, duration)
    tween.parallel().tween_property(ring.material_override, "albedo_color", Color(colour.r, colour.g, colour.b, 0.0), duration)
    tween.tween_callback(ring_root.queue_free)


func _play_impact(position: Vector3, colour: Color, radius: float, duration: float) -> void:
    var impact := Node3D.new()
    impact.name = "SpellImpact"
    impact.global_position = position
    add_child(impact)
    var core_material := _make_material(colour, 2.8, 0.72)
    var core := _add_sphere(impact, 0.45, core_material)
    core.scale = Vector3.ONE * 0.25
    var ring := _add_ring(impact, 1.0, _make_material(colour.lightened(0.3), 2.4, 0.9))
    ring.scale = Vector3.ONE * 0.2
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(core, "scale", Vector3.ONE * radius, duration)
    tween.parallel().tween_property(core_material, "albedo_color", Color(colour.r, colour.g, colour.b, 0.0), duration)
    tween.parallel().tween_property(ring, "scale", Vector3.ONE * radius * 1.45, duration)
    tween.parallel().tween_property(ring.material_override, "albedo_color", Color(colour.r, colour.g, colour.b, 0.0), duration)
    tween.tween_callback(impact.queue_free)


func _play_dome(position: Vector3, colour: Color, duration: float) -> void:
    var dome := Node3D.new()
    dome.global_position = position
    add_child(dome)
    var shell := _add_sphere(dome, 1.0, _make_material(colour, 1.3, 0.20))
    shell.scale = Vector3(0.25, 0.05, 0.25)
    var ring := _add_ring(dome, 1.0, _make_material(colour.lightened(0.2), 2.2, 0.9))
    ring.position.y = -0.45
    var tween := create_tween()
    tween.tween_property(shell, "scale", Vector3(1.0, 1.35, 1.0), duration * 0.45)
    tween.tween_interval(duration * 0.15)
    tween.tween_property(shell, "scale", Vector3(1.15, 1.5, 1.15), duration * 0.4)
    tween.parallel().tween_property(shell.material_override, "albedo_color", Color(colour.r, colour.g, colour.b, 0.0), duration)
    tween.tween_callback(dome.queue_free)


func _play_shield(position: Vector3, colour: Color, duration: float) -> void:
    _play_ring(position, colour, 0.2, 1.35, duration)
    var shield := Node3D.new()
    shield.global_position = position
    add_child(shield)
    var shell := _add_sphere(shield, 0.78, _make_material(colour, 2.2, 0.25))
    shell.scale = Vector3(0.55, 1.1, 0.55)
    var tween := create_tween()
    tween.tween_property(shell, "scale", Vector3(0.85, 1.35, 0.85), duration * 0.5)
    tween.parallel().tween_property(shell.material_override, "albedo_color", Color(colour.r, colour.g, colour.b, 0.0), duration)
    tween.tween_callback(shield.queue_free)


func _play_summon_circle(position: Vector3, colour: Color) -> void:
    _play_ring(position, colour, 0.1, 1.9, 1.0)
    _play_ring(position + Vector3.UP * 0.03, Color(0.88, 0.78, 0.48), 0.1, 1.25, 0.8)
    for index in range(6):
        var angle := TAU * float(index) / 6.0
        var point := position + Vector3(cos(angle), 0.05, sin(angle)) * 1.15
        _play_impact(point, colour, 0.16, 0.45)


func _play_counterspell(origin: Vector3, impact: Vector3) -> void:
    _play_projectile(origin, impact, Color(0.68, 0.42, 1.0), 0.22, 0.35)
    _play_ring(impact, Color(0.82, 0.65, 1.0), 0.1, 1.65, 0.55)
    _play_ring(impact, Color(0.42, 0.78, 1.0), 0.1, 1.15, 0.75)


func _play_entangle(position: Vector3, affected_actors: Array[Node3D]) -> void:
    _play_ring(position, Color(0.32, 0.72, 0.25), 0.2, 2.0, 1.1)
    for actor in affected_actors:
        if actor == null:
            continue
        var roots := Node3D.new()
        roots.global_position = actor.global_position
        add_child(roots)
        for index in range(3):
            var root := MeshInstance3D.new()
            var mesh := CylinderMesh.new()
            mesh.top_radius = 0.035
            mesh.bottom_radius = 0.09
            mesh.height = 0.9
            root.mesh = mesh
            root.material_override = _make_material(Color(0.30, 0.56, 0.20), 1.0)
            root.position = Vector3(float(index - 1) * 0.22, 0.42, 0.0)
            root.rotation.z = deg_to_rad(float(index - 1) * 18.0)
            roots.add_child(root)
        var tween := create_tween()
        tween.tween_property(roots, "scale", Vector3(1.0, 1.15, 1.0), 0.35)
        tween.tween_interval(0.25)
        tween.tween_callback(roots.queue_free)


func _play_shimmer(position: Vector3) -> void:
    _play_aura(position, Color(0.65, 0.78, 1.0), 1.1, 0.8)
    for index in range(5):
        var angle := TAU * float(index) / 5.0
        var point := position + Vector3(cos(angle), 0.65 + float(index % 2) * 0.28, sin(angle)) * 0.8
        _play_impact(point, Color(0.82, 0.90, 1.0), 0.18, 0.55)


func _play_rift(position: Vector3) -> void:
    _play_ring(position, Color(0.52, 0.22, 0.88), 1.7, 0.15, 0.65)
    _play_ring(position + Vector3.UP * 0.05, Color(0.22, 0.55, 1.0), 1.25, 0.1, 0.8)
    _play_aura(position, Color(0.38, 0.20, 0.72), 1.0, 0.9)


func _play_feather_fall(position: Vector3) -> void:
    _play_aura(position, Color(0.55, 0.82, 1.0), 1.0, 1.0)
    for index in range(5):
        var feather := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.045, 0.42, 0.12)
        feather.mesh = mesh
        feather.material_override = _make_material(Color(0.88, 0.94, 1.0), 1.2, 0.9)
        feather.global_position = position + Vector3(float(index - 2) * 0.28, 1.1 + float(index % 2) * 0.3, 0.0)
        feather.rotation.z = deg_to_rad(float(index - 2) * 13.0)
        add_child(feather)
        var tween := create_tween()
        tween.tween_property(feather, "global_position", feather.global_position + Vector3(0.0, -0.9, 0.0), 0.9)
        tween.parallel().tween_property(feather, "scale", Vector3.ONE * 0.3, 0.9)
        tween.tween_callback(feather.queue_free)
