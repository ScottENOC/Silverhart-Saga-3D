#!/usr/bin/env python3
"""Lazy local Ara -> Blender -> Silverhart runtime asset pipeline.

Caches each Ara export and Blender/assembly stage by a fingerprint of its inputs,
tool versions and relevant source scripts. Safe to rerun after interruption.
"""
from __future__ import annotations
import hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "build" / "local-cache" / "ara"
GEN = CACHE / "3d-gen"
RAW = CACHE / "generated"
ARA = ROOT / "art" / "characters" / "ara"
RUNTIME = ROOT / "art" / "characters" / "ara_runtime"
PIN = "b60b5bece6d383d2cbb7067fd50e7c8e68b5a395"
FILES = [
    "ara_person_benchmark.glb", "ara_person_body.glb", "ara_person_male_raw.glb",
    "ara_person_mobile.glb", "ara_person_tank_top.glb", "ara_person_halter_bra_lace.glb",
    "ara_person_halter_bra_fishnet.glb", "ara_person_triangle_bikini_top.glb",
    "ara_person_string_bikini_bottom.glb", "ara_person_lace_briefs.glb",
    "ara_person_fishnet_briefs.glb", "ara_person_lace_shirt.glb",
    "ara_person_fishnet_shirt.glb", "ara_person_lace_pants.glb",
    "ara_person_fishnet_pants.glb", "ara_person_wrapper_knee.glb", "ara_person_backless_slit_dress.glb",
    "ara_person_leather_armor.glb",
]
def log(s): print(f"\n[ Ara local ] {s}", flush=True)
def fail(s): raise SystemExit(f"\n[Error] {s}")
def command(name, override=None):
    value = override or shutil.which(name)
    if not value: fail(f"Cannot find {name}. Install it or set {name.upper()}_BIN.")
    return str(value)
def run(args, cwd=ROOT, env=None):
    log("$ " + " ".join(map(str,args)))
    subprocess.run(list(map(str,args)), cwd=cwd, env=env, check=True)

def run_pnpm(args, cwd):
    """Run the pinned pnpm via Corepack on Windows when no global shim exists."""
    pnpm = shutil.which("pnpm")
    if pnpm:
        run([pnpm, *args], cwd=cwd)
        return
    corepack = shutil.which("corepack")
    if not corepack:
        fail("Cannot find pnpm or Corepack. Install Node.js 20+ and enable Corepack.")
    command_line = "corepack pnpm@10.19.0 " + subprocess.list2cmdline(list(map(str, args)))
    log("$ " + command_line)
    subprocess.run(command_line, cwd=cwd, check=True, shell=True)
def digest(paths, extra=""):
    h=hashlib.sha256(extra.encode())
    for p in paths:
        p=Path(p)
        h.update(str(p).encode())
        if p.is_file():
            h.update(p.read_bytes())
        elif p.is_dir():
            for f in sorted(x for x in p.rglob("*") if x.is_file() and ".git" not in x.parts and "node_modules" not in x.parts):
                h.update(str(f.relative_to(p)).encode()); h.update(f.read_bytes())
    return h.hexdigest()
def cached(stage, outputs, inputs, extra, action):
    stamp=CACHE / "stamps" / f"{stage}.sha256"
    expected=digest(inputs, extra)
    if stamp.is_file() and stamp.read_text().strip()==expected and all(Path(x).is_file() and Path(x).stat().st_size for x in outputs):
        log(f"Cache hit: {stage}")
        return
    log(f"Building: {stage}")
    for out in outputs:
        Path(out).parent.mkdir(parents=True,exist_ok=True)
    action()
    missing=[str(x) for x in outputs if not Path(x).is_file() or not Path(x).stat().st_size]
    if missing: fail(f"{stage} did not produce: {', '.join(missing)}")
    stamp.parent.mkdir(parents=True,exist_ok=True); stamp.write_text(expected+"\n")
def main():
    CACHE.mkdir(parents=True,exist_ok=True); RAW.mkdir(parents=True,exist_ok=True); ARA.mkdir(parents=True,exist_ok=True)
    git=command("git"); node=command("node"); npm=command("npm"); blender=command("blender",os.environ.get("BLENDER_BIN"))
    py=sys.executable
    if not (GEN/".git").exists():
        log("Cloning pinned Ara 3D Gen source")
        run([git,"clone","https://github.com/olatunde85/3d-gen.git",GEN])
    current=subprocess.check_output([git,"rev-parse","HEAD"],cwd=GEN,text=True).strip()
    if current != PIN:
        run([git,"fetch","origin"],cwd=GEN); run([git,"checkout",PIN],cwd=GEN)
    if not (GEN/"node_modules").exists() or not (GEN/"node_modules/.modules.yaml").exists():
        run_pnpm(["install","--no-frozen-lockfile"],cwd=GEN)
    if not (GEN/"public"/"assets").exists() or not any((GEN/"public"/"assets").iterdir()):
        run([npm,"run","setup-assets"],cwd=GEN)
    patch=ROOT/"tools/ara/patch_layering.py"
    patch_stamp=CACHE/"stamps"/"layering-patch.sha256"
    patch_hash=digest([patch],PIN)
    if not patch_stamp.is_file() or patch_stamp.read_text().strip()!=patch_hash:
        run([py,patch],cwd=GEN)
        patch_stamp.parent.mkdir(parents=True,exist_ok=True); patch_stamp.write_text(patch_hash+"\\n")
    base={
      "name":"Ara Base Person - dressed preview","seed":218,"gender":0,"age":0.5,
      "muscle":0.5,"weight":0.5,"height":0.5,"proportions":0.5,
      "african":0.05,"asian":0.05,"caucasian":0.9,"breastSize":0.5,"breastFirmness":0.55,
      "hair":"short02","hairTint":"#2a1e16","outfit":"none","top":"fatigue_shirt",
      "underTop":"bra","underBottom":"briefs","jacket":"none","bottom":"fatigue_pants",
      "underwear":False,"shoes":"combat_boots","hat":"none","weapon":"none","carry":"none",
      "detail":"high","rig":"game","restPose":"A","animations":True,"faceBones":True,
      "faceShapes":True,"speechShapes":True,"expression":"neutral",
      "garmentStyles":{
        "fatigue_shirt":{"pattern":"solid","color":"#52606b","color2":"#3d4852"},
        "bra":{"pattern":"solid","color":"#3d4147","color2":"#22262b"},
        "tank_top":{"pattern":"solid","color":"#52606b","color2":"#3d4852"},
        "bikini_top":{"pattern":"solid","color":"#3d4147","color2":"#22262b"},
        "bikini_bottom":{"pattern":"solid","color":"#3d4147","color2":"#22262b"},
        "fatigue_pants":{"pattern":"solid","color":"#35383d","color2":"#35383d"}}}
    body=dict(base); body.update({"name":"Ara Base Person - body no clothing","outfit":"none","top":"none","jacket":"none","bottom":"none","underTop":"none","underBottom":"none","underwear":False,"shoes":"none","hat":"none","accessories":[],"earrings":"none","tattoos":[]})
    male=dict(body); male.update({"name":"Ara Base Person - male body","seed":417,"gender":1,"breastSize":0,"breastFirmness":0})
    mobile=dict(base); mobile.update({"name":"Ara Base Person - mobile preview","detail":"low","animations":False,"faceBones":False,"faceShapes":False,"speechShapes":False})
    variants={
      "tank_top":{"top":"tank_top","underTop":"none","underBottom":"none","bottom":"none"},
      "wrapper_knee":{"top":"none","underTop":"none","underBottom":"none","bottom":"wrapper_knee"},
      "halter_bra_lace":{"top":"none","underTop":"halter_bra_lace","underBottom":"none","bottom":"none","garmentStyles":{"halter_bra_lace":{"pattern":"lace","color":"#29242d","color2":"#987b91"}}},
      "halter_bra_fishnet":{"top":"none","underTop":"halter_bra_fishnet","underBottom":"none","bottom":"none","garmentStyles":{"halter_bra_fishnet":{"pattern":"fishnet","color":"#29242d","color2":"#987b91"}}},
      "triangle_bikini_top":{"top":"none","underTop":"bikini_top","underBottom":"none","bottom":"none"},
      "string_bikini_bottom":{"top":"none","underTop":"none","underBottom":"bikini_bottom","bottom":"none"},
      "lace_briefs":{"top":"none","underTop":"none","underBottom":"bikini_bottom","bottom":"none","garmentStyles":{"bikini_bottom":{"pattern":"lace","color":"#29242d","color2":"#987b91"}}},
      "fishnet_briefs":{"top":"none","underTop":"none","underBottom":"bikini_bottom","bottom":"none","garmentStyles":{"bikini_bottom":{"pattern":"fishnet","color":"#29242d","color2":"#987b91"}}},
      "lace_shirt":{"top":"fatigue_shirt","underTop":"none","underBottom":"none","bottom":"none","garmentStyles":{"fatigue_shirt":{"pattern":"lace","color":"#29242d","color2":"#987b91"}}},
      "fishnet_shirt":{"top":"fatigue_shirt","underTop":"none","underBottom":"none","bottom":"none","garmentStyles":{"fatigue_shirt":{"pattern":"fishnet","color":"#29242d","color2":"#987b91"}}},
      "lace_pants":{"top":"none","underTop":"none","underBottom":"none","bottom":"fatigue_pants","garmentStyles":{"fatigue_pants":{"pattern":"lace","color":"#29242d","color2":"#987b91"}}},
      "fishnet_pants":{"top":"none","underTop":"none","underBottom":"none","bottom":"fatigue_pants","garmentStyles":{"fatigue_pants":{"pattern":"fishnet","color":"#29242d","color2":"#987b91"}}},
      "backless_slit_dress":{"top":"backless_slit_dress","underTop":"none","underBottom":"none","bottom":"none"},
      "leather_armor":{"top":"none","underTop":"none","underBottom":"none","bottom":"none","accessories":["leather_armor"]}}
    params={"ara_person_benchmark":base,"ara_person_body":body,"ara_person_male_raw":male,"ara_person_mobile":mobile,"ara_person_wrapper_knee":dict(body, name="Ara Wrapper Knee Source", bottom="wrapper_knee")}
    for k,v in variants.items():
        p=dict(base); p.update({"name":"Ara Base Person - "+k,"jacket":"none","underwear":False,"shoes":"none","hat":"none","weapon":"none","carry":"none"}); p.update(v); params["ara_person_"+k]=p
    def export(key,p):
        param=RAW/(key+".params.json"); param.write_text(json.dumps(p,indent=2)+"\n")
        out=RAW/(key+"-out"); glb=RAW/(key+".glb")
        def action():
            shutil.rmtree(out,ignore_errors=True); out.mkdir(parents=True,exist_ok=True)
            run([npm,"run","export","--","--params",param,"--detail",p.get("detail","high"),"--formats","glb","--out",out],cwd=GEN)
            found=next(out.glob("*.glb"),None)
            if not found: fail(f"Ara export {key} produced no GLB")
            shutil.copy2(found,glb)
        cached("ara-"+key,[glb],[param,patch],PIN+":"+str(current),action)
        shutil.copy2(glb,ARA/(key+".glb")); shutil.copy2(param,ARA/(key+".params.json"))
    for key,p in params.items(): export(key,p)
    # Anatomy integration: female base and male base, cached separately.
    female_out=ARA/"ara_person_body.glb"; female_raw=RAW/"ara_person_body.glb"
    # Use generated raw body as input; retain a distinct output so cache is safe.
    def female():
        env=os.environ.copy(); env.update({"ARA_INPUT":str(female_raw),"ARA_OUTPUT":str(RAW/"ara_person_body_anatomy.glb"),"ARA_PROFILE":"female","ARA_ADULT":"1"})
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py"],env=env)
        shutil.copy2(RAW/"ara_person_body_anatomy.glb",female_out)
    cached("female-anatomy",[female_out],[female_raw,ROOT/"tools/blender/add_adult_anatomy.py"],"blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],female)
    male_out=ARA/"ara_person_male_body.glb"; male_raw=RAW/"ara_person_male_raw.glb"
    def male_action():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_male_anatomy.py","--","--input",male_raw,"--output",male_out,"--adult","--profile-name","standard"])
    cached("male-anatomy",[male_out],[male_raw,ROOT/"tools/blender/add_male_anatomy.py"],"blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],male_action)
    # Modular GLB assembly, then dress slit and garment fitting.
    modular=RAW/"ara_person_modular_assembled.glb"; underwear=RAW/"ara_person_modular_underwear_assembled.glb"
    benchmark=ARA/"ara_person_benchmark.glb"; body_final=female_out
    def assemble():
        args=[py,ROOT/"tools/ara/assemble_modular_glb.py",body_final,modular,
          benchmark,"Fatigue pants#1",benchmark,"Fatigue pants#2",
          ARA/"ara_person_backless_slit_dress.glb","Backless slit dress",
          ARA/"ara_person_backless_slit_dress.glb","Pencil skirt",
          benchmark,"Shoes",benchmark,"Boot shafts",benchmark,"Fatigue shirt",benchmark,"Bra",
          ARA/"ara_person_halter_bra_lace.glb","Halter lace bra cups",
          ARA/"ara_person_halter_bra_lace.glb","Halter lace bra piping",
          ARA/"ara_person_halter_bra_lace.glb","Halter lace bra straps",
          ARA/"ara_person_halter_bra_fishnet.glb","Halter fishnet bra cups",
          ARA/"ara_person_halter_bra_fishnet.glb","Halter fishnet bra straps",
          benchmark,"Briefs",ARA/"ara_person_tank_top.glb","Tank top",
          ARA/"ara_person_triangle_bikini_top.glb","Bikini top=Triangle bikini top",
          ARA/"ara_person_triangle_bikini_top.glb","Bikini strings*=Triangle bikini strings",
          ARA/"ara_person_string_bikini_bottom.glb","Bikini bottom=String bikini bottom",
          ARA/"ara_person_string_bikini_bottom.glb","Bikini strings*=String bikini strings",
          ARA/"ara_person_lace_briefs.glb","Bikini bottom=Lace briefs",
          ARA/"ara_person_lace_briefs.glb","Bikini strings*=Lace briefs ties",
          ARA/"ara_person_fishnet_briefs.glb","Bikini bottom=Fishnet briefs",
          ARA/"ara_person_fishnet_briefs.glb","Bikini strings*=Fishnet briefs ties",
          ARA/"ara_person_lace_shirt.glb","Fatigue shirt=Lace shirt",
          ARA/"ara_person_fishnet_shirt.glb","Fatigue shirt=Fishnet shirt",
          ARA/"ara_person_lace_pants.glb","Fatigue pants#1=Lace pants",
          ARA/"ara_person_lace_pants.glb","Fatigue pants#2=Lace pants",
          ARA/"ara_person_fishnet_pants.glb","Fatigue pants#1=Fishnet pants",
          ARA/"ara_person_fishnet_pants.glb","Fatigue pants#2=Fishnet pants"]
        run(args)
        args2=[py,ROOT/"tools/ara/assemble_modular_glb.py",body_final,underwear,
          benchmark,"Fatigue shirt",benchmark,"Bra",
          ARA/"ara_person_halter_bra_lace.glb","Halter lace bra cups",
          ARA/"ara_person_halter_bra_lace.glb","Halter lace bra piping",
          ARA/"ara_person_halter_bra_lace.glb","Halter lace bra straps",
          ARA/"ara_person_halter_bra_fishnet.glb","Halter fishnet bra cups",
          ARA/"ara_person_halter_bra_fishnet.glb","Halter fishnet bra straps",
          benchmark,"Briefs",ARA/"ara_person_tank_top.glb","Tank top",
          ARA/"ara_person_triangle_bikini_top.glb","Bikini top=Triangle bikini top",
          ARA/"ara_person_triangle_bikini_top.glb","Bikini strings*=Triangle bikini strings",
          ARA/"ara_person_string_bikini_bottom.glb","Bikini bottom=String bikini bottom",
          ARA/"ara_person_string_bikini_bottom.glb","Bikini strings*=String bikini strings",
          ARA/"ara_person_lace_briefs.glb","Bikini bottom=Lace briefs",
          ARA/"ara_person_lace_briefs.glb","Bikini strings*=Lace briefs ties",
          ARA/"ara_person_fishnet_briefs.glb","Bikini bottom=Fishnet briefs",
          ARA/"ara_person_fishnet_briefs.glb","Bikini strings*=Fishnet briefs ties"]
        run(args2)
    inputs=[body_final,benchmark]+[ARA/f"ara_person_{x}.glb" for x in ["backless_slit_dress","halter_bra_lace","halter_bra_fishnet","tank_top","triangle_bikini_top","string_bikini_bottom","lace_briefs","fishnet_briefs","lace_shirt","fishnet_shirt","lace_pants","fishnet_pants"]]+[ROOT/"tools/ara/assemble_modular_glb.py"]
    cached("modular-assembly",[modular,underwear],inputs,"schema-1",assemble)
    env=os.environ.copy()
    env.update({"EGL_PLATFORM":"surfaceless","LIBGL_ALWAYS_SOFTWARE":"1"})
    fitted=RAW/"ara_person_modular_fitted.glb"
    def fit():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_dress_slit.py","--","--input",modular,"--output",RAW/"slit.glb"],env=env)
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py","--","--input",RAW/"slit.glb","--output",fitted,"--profile","none","--adult","--fit-existing"],env=env)
        shutil.copy2(fitted,modular)
        fitted_under=RAW/"underwear_fitted.glb"
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py","--","--input",underwear,"--output",fitted_under,"--profile","none","--adult","--fit-existing"],env=env)
        shutil.copy2(fitted_under,underwear)
    cached("garment-fit",[modular,underwear],inputs+[ROOT/"tools/blender/add_dress_slit.py",ROOT/"tools/blender/add_adult_anatomy.py"],"blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],fit)
    # Convert combined Ara/NPC clothing surfaces into independently skinned
    # garment objects. This is local Blender work, never a GitHub Actions job.
    garments=RAW/"ara_person_garments.glb"
    npc_manifest=ROOT/"data/characters/hollowmere_npcs.json"
    npc_profiles=json.loads(npc_manifest.read_text(encoding="utf-8"))["characters"]
    # Hollowmere GLBs use game_id filenames (e.g. companion_wren_talbot.glb).
    npc_models=[
        ROOT/"art/characters/hollowmere"/(str(profile.get("game_id") or profile.get("id") or "")+".glb")
        for profile in npc_profiles
    ]
    garment_builder=ROOT/"tools/blender/build_ara_garment_library.py"
    garment_report=garments.with_suffix(".report.json")
    def build_garment_library():
        run([blender,"--background","--python-exit-code","1","--python",garment_builder,
          "--","--base-body",female_out,"--modular",modular,"--underwear",underwear,
          "--armor",ARA/"ara_person_leather_armor.glb","--wrapper-knee",ARA/"ara_person_wrapper_knee.glb","--npc-manifest",npc_manifest,
          "--npc-dir",ROOT/"art/characters/hollowmere","--output",garments])
        if not garment_report.is_file():
            fail("Garment builder completed without its skinning validation report.")
    cached("garment-library",[garments,garment_report],
      [female_out,modular,underwear,ARA/"ara_person_leather_armor.glb",ARA/"ara_person_wrapper_knee.glb",npc_manifest,*npc_models,garment_builder],
      "garment-library-v2-game-id-skin-validation:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
      build_garment_library)

    # Review renders are also cached independently, so changing one outfit
    # review does not regenerate Ara meshes or rerun anatomy integration.
    review_root=ARA/"review"
    review_env=os.environ.copy(); review_env.update({"EGL_PLATFORM":"surfaceless","LIBGL_ALWAYS_SOFTWARE":"1"})
    def review_character(label, model, folder):
        outputs=[review_root/folder/f"{view}.png" for view in ["front","side","rear","three_quarter"]]
        def action():
            outdir=review_root/folder; outdir.mkdir(parents=True,exist_ok=True)
            env2=review_env.copy(); env2.update({"REVIEW_INPUT":str(model),"REVIEW_OUTPUT_DIR":str(outdir)})
            run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/inspect_character.py"],env=env2)
        cached("review-"+label,outputs,[model,ROOT/"tools/blender/inspect_character.py"],"blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],action)
    review_character("female-body",female_out,"body")
    review_character("male-body",male_out,"male")
    outfit_script=ROOT/"tools/review/render_modular_outfits.py"
    for outfit in ["dress","lace_bra","fishnet_bra","lace_briefs","fishnet_briefs","lace_shirt","fishnet_shirt","lace_pants","fishnet_pants"]:
        outputs=[review_root/"outfits"/outfit/f"{view}.png" for view in ["front","side","rear"]]+[review_root/"outfits"/outfit/"report.json"]
        def render_action(outfit=outfit):
            outdir=review_root/"outfits"
            run([blender,"--background","--python-exit-code","1","--python",outfit_script,"--",fitted,outdir,outfit],env=review_env)
        cached("review-outfit-"+outfit,outputs,[fitted,outfit_script],"blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],render_action)

    # Package exact files consumed by the game; include checksums and provenance.
    package=RUNTIME
    sources={
        "ara_person_benchmark.glb": ARA/"ara_person_benchmark.glb",
        "ara_person_body.glb": ARA/"ara_person_body.glb",
        "ara_person_modular.glb": modular,
        "ara_person_modular_underwear.glb": underwear,
        "ara_person_male_body.glb": ARA/"ara_person_male_body.glb",
        "ara_person_garments.glb": garments,
    }
    names=list(sources)
    def pack():
        package.mkdir(parents=True,exist_ok=True)
        for name,source in sources.items():
            if not source.is_file():
                fail(f"Runtime package source missing: {source}")
            shutil.copy2(source,package/name)
        assets={}
        for name in names:
            b=(package/name).read_bytes(); assets[name]={"size_bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
        manifest={"schema_version":1,"package_version":"local-"+digest(list(sources.values()))[:16],"source_commit":current,"generator":{"repository":"https://github.com/olatunde85/3d-gen","commit":PIN},"assets":assets}
        (package/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    cached("runtime-package",[package/"manifest.json"]+[package/n for n in names],list(sources.values()),"runtime-package-v2",pack)
    log("Ara + Blender runtime assets ready. Cached stages will be skipped on the next run.")

if __name__=="__main__":
    main()
