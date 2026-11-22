extends SceneTree
## Draft-only geometric proposal for Wren bra anatomy. Not approved production data.
## Uses the exact native Wren mesh and never writes the production mask manifest.
const MODEL_PATH := "res://build/wren-native/Wren.glb"
const OUTPUT_PATH := "res://build/wren-bra-proposal"
const MASK_SCRIPT := preload("res://scripts/characters/character_surface_region_mask.gd")
const SIZE := Vector2i(1200, 1000)
const REGIONS := {
 "breast_left": [Vector3(-0.115,1.190,0.175),Vector3(0.105,0.105,0.105),Color("#ef476f")],
 "breast_right": [Vector3(0.115,1.190,0.175),Vector3(0.105,0.105,0.105),Color("#f78c6b")],
 "chest_front_left": [Vector3(-0.115,1.285,0.105),Vector3(0.145,0.105,0.075),Color("#ffd166")],
 "chest_front_right": [Vector3(0.115,1.285,0.105),Vector3(0.145,0.105,0.075),Color("#06d6a0")],
 "pectoral_left": [Vector3(-0.145,1.325,0.055),Vector3(0.125,0.095,0.095),Color("#118ab2")],
 "pectoral_right": [Vector3(0.145,1.325,0.055),Vector3(0.125,0.095,0.095),Color("#9b5de5")],
 "sternum": [Vector3(0.0,1.235,0.155),Vector3(0.052,0.165,0.105),Color("#f4a261")],
 "underbust": [Vector3(0.0,1.075,0.115),Vector3(0.245,0.055,0.095),Color("#e9c46a")],
 "ribcage_left": [Vector3(-0.155,1.105,0.045),Vector3(0.115,0.135,0.115),Color("#2a9d8f")],
 "ribcage_right": [Vector3(0.155,1.105,0.045),Vector3(0.115,0.135,0.115),Color("#457b9d")],
 "clavicle_left": [Vector3(-0.105,1.405,0.025),Vector3(0.115,0.045,0.085),Color("#a8dadc")],
 "clavicle_right": [Vector3(0.105,1.405,0.025),Vector3(0.115,0.045,0.085),Color("#ffafcc")]
}
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 root.size = SIZE
 stage = Node3D.new()
 root.add_child(stage)
 _light()
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.current = true
 stage.add_child(camera)
 var packed := load(MODEL_PATH) as PackedScene
 if packed == null:
  push_error("Missing native Wren build")
  quit(1)
  return
 var body := packed.instantiate() as Node3D
 stage.add_child(body)
 await process_frame
 var mi := _find_mesh(body)
 if mi == null:
  push_error("Skin_Anatomy mesh not found")
  quit(1)
  return
 var si := -1
 for i in mi.mesh.get_surface_count():
  if mi.mesh.surface_get_name(i) == "Skin_Anatomy":
   si = i
   break
 if si < 0:
  push_error("Skin_Anatomy surface not found")
  quit(1)
  return
 var arrays := mi.mesh.surface_get_arrays(si)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
 var marker := SphereMesh.new()
 marker.radius = 0.0032
 marker.height = 0.0064
 marker.radial_segments = 5
 marker.rings = 3
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.vertex_color_use_as_albedo = true
 material.no_depth_test = true
 marker.material = material
 var transforms: Array[Transform3D] = []
 var colours: Array[Color] = []
 var counts := {}
 for id in REGIONS:
  var def: Array = REGIONS[id]
  var centre: Vector3 = def[0]
  var radii: Vector3 = def[1]
  var count := 0
  for v in vertices:
   if ((v - centre) / radii).length() <= 1.0:
    count += 1
    transforms.append(mi.global_transform * Transform3D(Basis.IDENTITY,v))
    colours.append(def[2])
  counts[id] = count
 var mm := MultiMesh.new()
 mm.transform_format = MultiMesh.TRANSFORM_3D
 mm.use_colors = true
 mm.mesh = marker
 mm.instance_count = transforms.size()
 for n in transforms.size():
  mm.set_instance_transform(n,transforms[n])
  mm.set_instance_color(n,colours[n])
 var overlay := MultiMeshInstance3D.new()
 overlay.multimesh = mm
 stage.add_child(overlay)
 var out := ProjectSettings.globalize_path(OUTPUT_PATH)
 DirAccess.make_dir_recursive_absolute(out)
 var views := {
  "front":[Vector3(0,1.23,4.2),Vector3(0,1.23,0),0.78],
  "side":[Vector3(4.2,1.23,0),Vector3(0,1.23,0),0.78],
  "rear":[Vector3(0,1.23,-4.2),Vector3(0,1.23,0),0.78]
 }
 for name in views:
  var view: Array = views[name]
  camera.position = view[0]
  camera.look_at(view[1],Vector3.UP)
  camera.size = view[2]
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  var img := root.get_texture().get_image()
  if img.save_png(out.path_join(name+"-candidate.png")) != OK:
   push_error("Failed saving proposal preview")
   quit(1)
   return
 var proposal := {
  "status":"DRAFT_PROPOSAL_NOT_APPROVED",
  "character":"Wren",
  "model":MODEL_PATH,
  "surface_name":"Skin_Anatomy",
  "surface_index":si,
  "vertex_count":vertices.size(),
  "triangle_count":indices.size()/3,
  "surface_signature":MASK_SCRIPT.build_surface_signature(mi.mesh,si),
  "regions":REGIONS,
  "candidate_vertex_counts":counts,
  "method":"Independent overlapping ellipsoidal spatial selections on exact native Wren rest vertices.",
  "limitations":["Centres and radii are geometric hypotheses, not artist-authored anatomy.","Binary vertex selections are preview-only; approved production weights require visual review and refined falloffs.","This file is not loaded by the production mask manifest and must not drive garment generation."]
 }
 var f := FileAccess.open(out.path_join("proposal.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(proposal,"\t"))
 f.close()
 print("WREN_BRA_PROPOSAL_OK vertices=%d regions=%d" % [vertices.size(),REGIONS.size()])
 quit(0)

func _find_mesh(node: Node) -> MeshInstance3D:
 if node is MeshInstance3D and node.mesh != null:
  for i in node.mesh.get_surface_count():
   if node.mesh.surface_get_name(i) == "Skin_Anatomy":
    return node
 for child in node.get_children():
  var found := _find_mesh(child)
  if found != null:
   return found
 return null

func _light() -> void:
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("#252a30")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("#c5cbd2")
 env.ambient_light_energy = 0.7
 var world := WorldEnvironment.new()
 world.environment = env
 stage.add_child(world)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-25,-25,0)
 light.light_energy = 1.3
 stage.add_child(light)
