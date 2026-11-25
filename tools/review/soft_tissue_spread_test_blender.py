import bpy
import json
import math
import os
from mathutils import Vector

OUT = bpy.path.abspath("//build/soft-tissue-spread")
os.makedirs(OUT, exist_ok=True)

# Controlled geometric experiment, not a physical solver:
# compare a narrow Gaussian indentation with a broad, smoothly propagated one.
DEPTH = 0.050
PENCIL_RADIUS = 0.005
PATCH_HALF_WIDTH = 0.060
GRID_STEP = 0.001
LOCAL_LENGTH = 0.010
BROAD_LENGTH = 0.050
CENTRES = {"localised": -0.075, "propagated": 0.075}

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness=0.75):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = roughness
    return mat

surface_mat = material("Soft tissue surface", (0.58, 0.28, 0.24))
pencil_mat = material("Rigid 10 mm pencil", (0.16, 0.19, 0.23), 0.35)
wire_mat = material("Surface grid", (0.12, 0.07, 0.06))
label_mat = material("Labels", (0.035, 0.035, 0.035))

def make_surface(name, centre_x, length_scale):
    count = int((2 * PATCH_HALF_WIDTH) / GRID_STEP) + 1
    verts = []
    faces = []
    for j in range(count):
        y = -PATCH_HALF_WIDTH + j * GRID_STEP
        for i in range(count):
            x = -PATCH_HALF_WIDTH + i * GRID_STEP
            radius = math.sqrt(x*x + y*y)
            # The centre is displaced 50 mm; displacement decays continuously.
            # The profile is deliberately prescribed to isolate spread behaviour.
            dz = -DEPTH * math.exp(-((radius / length_scale) ** 2))
            verts.append((centre_x + x, y, dz))
    for j in range(count - 1):
        for i in range(count - 1):
            a = j * count + i
            faces.append((a, a+1, a+1+count, a+count))
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(surface_mat)
    # A fine wire overlay makes the deformation gradient visible.
    wire = obj.modifiers.new("Fine diagnostic grid", "WIREFRAME")
    wire.thickness = 0.00012
    wire.use_replace = False
    wire.material_offset = 0
    obj["profile_length_scale_mm"] = length_scale * 1000.0
    obj["maximum_prescribed_displacement_mm"] = DEPTH * 1000.0
    return obj

def make_pencil(name, centre_x):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=64, radius=PENCIL_RADIUS, depth=0.115,
        location=(centre_x, 0.0, 0.0075)
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(pencil_mat)
    bevel = obj.modifiers.new("Soft pencil edge", "BEVEL")
    bevel.width = 0.0007
    bevel.segments = 3
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj

def make_text(body, location, size=0.006):
    curve = bpy.data.curves.new("Label", "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = 0
    obj = bpy.data.objects.new(body, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (math.radians(90), 0, 0)
    obj.data.materials.append(label_mat)
    return obj

make_surface("Localised deformation (10 mm spread scale)", CENTRES["localised"], LOCAL_LENGTH)
make_surface("Propagated deformation (50 mm spread scale)", CENTRES["propagated"], BROAD_LENGTH)
make_pencil("Rigid pencil - localised case", CENTRES["localised"])
make_pencil("Rigid pencil - propagated case", CENTRES["propagated"])
make_text("NARROW PROFILE", (-0.125, -0.064, 0.030), 0.006)
make_text("BROAD PROPAGATION", (0.020, -0.064, 0.030), 0.006)

# Lighting and a near-side orthographic camera show the hidden indentation profile.
world = bpy.context.scene.world
world.color = (0.8, 0.8, 0.8)
bpy.ops.object.light_add(type="AREA", location=(0.0, -0.18, 0.16))
light = bpy.context.object
light.data.energy = 450
light.data.shape = "DISK"
light.data.size = 0.25
bpy.ops.object.camera_add(location=(0.0, -0.42, 0.105))
camera = bpy.context.object
direction = Vector((0.0, 0.0, -0.010)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 0.31
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 64
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(OUT, "soft-tissue-spread-comparison.png")
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.image_settings.color_mode = "RGBA"
bpy.ops.render.render(write_still=True)

# Sample the prescribed displacement field at and beyond the pencil edge.
radii_mm = [0.0, 5.0, 5.5, 10.0, 20.0, 30.0, 50.0]
profiles = {}
for name, scale in (("localised", LOCAL_LENGTH), ("propagated", BROAD_LENGTH)):
    profiles[name] = []
    for radius_mm in radii_mm:
        r = radius_mm / 1000.0
        displacement_mm = DEPTH * math.exp(-((r / scale) ** 2)) * 1000.0
        profiles[name].append({
            "radius_from_pencil_centre_mm": radius_mm,
            "vertical_displacement_mm": round(displacement_mm, 3)
        })

report = {
    "test": "10 mm rigid cylindrical indenter; prescribed 50 mm maximum surface displacement",
    "purpose": "Compare a narrow localised deformation profile with a broad propagated profile and quantify displacement outside the indenter footprint.",
    "parameters": {
        "pencil_diameter_mm": PENCIL_RADIUS * 2000.0,
        "maximum_displacement_mm": DEPTH * 1000.0,
        "localised_profile_length_scale_mm": LOCAL_LENGTH * 1000.0,
        "propagated_profile_length_scale_mm": BROAD_LENGTH * 1000.0,
        "surface_grid_spacing_mm": GRID_STEP * 1000.0,
        "surface_patch_width_mm": PATCH_HALF_WIDTH * 2000.0
    },
    "profiles": profiles,
    "interpretation": {
        "at_5_5mm_outside_pencil_edge": {
            "localised_mm": profiles["localised"][2]["vertical_displacement_mm"],
            "propagated_mm": profiles["propagated"][2]["vertical_displacement_mm"]
        },
        "caveat": "This is a controlled geometric profile comparison, not a material simulation. The broad profile is prescribed with a Gaussian length scale; it does not yet solve elasticity, incompressibility, volume conservation, friction, contact forces, or large-strain mechanics."
    }
}
with open(os.path.join(OUT, "soft-tissue-spread-report.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
