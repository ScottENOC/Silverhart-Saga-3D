#!/usr/bin/env python3
"""Lazy local Ara -> Blender -> Silverhart runtime asset pipeline.

Caches each Ara export and Blender/assembly stage by a fingerprint of its inputs,
tool versions and relevant source scripts. Safe to rerun after interruption.
"""
from __future__ import annotations
import hashlib, json, os, shutil, subprocess, sys
from pathlib import Path
from character_definitions import DEFAULT_MALE_BODY_MODIFIERS, ara_export_params, load_item_catalog, validate_character_definitions

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

def patch_ara_windows_target_paths():
    """Make MakeHuman target keys use portable forward slashes on Windows."""
    builder = GEN / "scripts" / "build-assets.ts"
    source = builder.read_text(encoding="utf-8")
    old = "relative(join(MH, 'targets'), p).replace(/\\.target$/, '')"
    new = "relative(join(MH, 'targets'), p).replace(/\\\\/g, '/').replace(/\\.target$/, '')"
    old_count = source.count(old)
    new_count = source.count(new)
    if old_count == 2:
        builder.write_text(source.replace(old, new), encoding="utf-8")
        log("Patched Ara target-key path separators for Windows.")
    elif new_count == 2:
        log("Ara target-key path separators are already portable.")
    else:
        fail(
            "Unexpected Ara build-assets.ts target-key code: "
            f"expected two original or two patched expressions, found {old_count} and {new_count}."
        )

def ara_target_assets_need_rebuild():
    """Detect the empty target pack/catalog produced by the Windows path bug."""
    assets = GEN / "public" / "assets"
    targets = assets / "targets.pack"
    catalog = assets / "catalog.json"
    if not targets.is_file() or not catalog.is_file() or targets.stat().st_size <= 153:
        return True
    try:
        sliders = json.loads(catalog.read_text(encoding="utf-8")).get("sliders")
        return not isinstance(sliders, list) or not sliders
    except (OSError, ValueError, TypeError):
        return True

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
FORCE_REBUILD = False
MAX_CACHE_AGE_HOURS = None

def file_sha256(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def digest(paths, extra=""):
    """Fingerprint every declared input by content; missing inputs are errors."""
    h = hashlib.sha256(extra.encode("utf-8"))
    for item in paths:
        path = Path(item)
        if not path.exists():
            fail(f"Cache input does not exist: {path}")
        h.update(str(path.resolve()).encode("utf-8"))
        if path.is_file():
            h.update(file_sha256(path).encode("ascii"))
        elif path.is_dir():
            files = sorted(
                f for f in path.rglob("*")
                if f.is_file()
                and ".git" not in f.parts
                and "node_modules" not in f.parts
            )
            for file in files:
                h.update(str(file.relative_to(path)).encode("utf-8"))
                h.update(file_sha256(file).encode("ascii"))
    return h.hexdigest()

def cached(stage, outputs, inputs, extra, action):
    """Run a stage unless its inputs, outputs and optional age prove it reusable."""
    stamp = CACHE / "stamps" / f"{stage}.json"
    expected = digest(inputs, extra)
    output_paths = [Path(x) for x in outputs]
    valid = False
    reason = "no valid stage manifest"

    if not FORCE_REBUILD and stamp.is_file():
        try:
            record = json.loads(stamp.read_text(encoding="utf-8"))
            if record.get("schema_version") != 2:
                reason = "old cache-manifest schema"
            elif record.get("fingerprint") != expected:
                reason = "input fingerprint changed"
            else:
                recorded_outputs = record.get("outputs", {})
                output_ok = all(
                    path.is_file()
                    and path.stat().st_size > 0
                    and recorded_outputs.get(str(path)) == {
                        "size_bytes": path.stat().st_size,
                        "sha256": file_sha256(path),
                    }
                    for path in output_paths
                )
                if not output_ok:
                    reason = "one or more cached outputs are missing or modified"
                else:
                    age_ok = True
                    if MAX_CACHE_AGE_HOURS is not None:
                        from datetime import datetime, timezone
                        built_at = record.get("built_at_utc")
                        built = datetime.fromisoformat(built_at.replace("Z", "+00:00"))
                        age_hours = (datetime.now(timezone.utc) - built).total_seconds() / 3600
                        age_ok = 0 <= age_hours <= MAX_CACHE_AGE_HOURS
                        if not age_ok:
                            reason = f"cache is older than {MAX_CACHE_AGE_HOURS:g} hours"
                    valid = age_ok
        except (OSError, ValueError, TypeError, AttributeError):
            reason = "unreadable or incomplete cache manifest"

    if valid:
        log(f"Cache hit: {stage} (inputs and output checksums match)")
        return

    if FORCE_REBUILD:
        reason = "--force requested"
    log(f"Building: {stage} ({reason})")
    for output in output_paths:
        output.parent.mkdir(parents=True, exist_ok=True)
    action()

    missing = [str(path) for path in output_paths if not path.is_file() or path.stat().st_size == 0]
    if missing:
        fail(f"{stage} did not produce: {', '.join(missing)}")

    from datetime import datetime, timezone
    record = {
        "schema_version": 2,
        "stage": stage,
        "fingerprint": expected,
        "built_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "outputs": {
            str(path): {
                "size_bytes": path.stat().st_size,
                "sha256": file_sha256(path),
            }
            for path in output_paths
        },
    }
    stamp.parent.mkdir(parents=True, exist_ok=True)
    temporary_stamp = stamp.with_suffix(".json.tmp")
    temporary_stamp.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    temporary_stamp.replace(stamp)

def parse_build_options():
    import argparse
    parser = argparse.ArgumentParser(description="Build Ara character assets for Silverhart locally.")
    parser.add_argument("--force", action="store_true",
                        help="Ignore all stage caches and rebuild every generated stage.")
    parser.add_argument("--max-cache-age-hours", type=float, default=None,
                        help="Rebuild a stage if its successful cache manifest is older than this many hours.")
    parser.add_argument("--anatomy-review-only", action="store_true",
                        help="Build only female_average and male_average anatomy review assets; skip clothing/NPC pipeline.")
    options = parser.parse_args()
    if options.max_cache_age_hours is not None and options.max_cache_age_hours < 0:
        parser.error("--max-cache-age-hours must be zero or greater")
    return options

def main():
    global FORCE_REBUILD, MAX_CACHE_AGE_HOURS
    options = parse_build_options()
    FORCE_REBUILD = options.force
    MAX_CACHE_AGE_HOURS = options.max_cache_age_hours
    CACHE.mkdir(parents=True,exist_ok=True); RAW.mkdir(parents=True,exist_ok=True); ARA.mkdir(parents=True,exist_ok=True)
    if FORCE_REBUILD:
        log("Forced rebuild: all cached stages will be regenerated.")
    if MAX_CACHE_AGE_HOURS is not None:
        log(f"Cache age limit: {MAX_CACHE_AGE_HOURS:g} hours.")
    git=command("git"); node=command("node"); npm=command("npm"); blender=command("blender",os.environ.get("BLENDER_BIN"))
    py=sys.executable
    if not (GEN/".git").exists():
        log("Cloning pinned Ara 3D Gen source")
        run([git,"clone","https://github.com/olatunde85/3d-gen.git",GEN])
    current=subprocess.check_output([git,"rev-parse","HEAD"],cwd=GEN,text=True).strip()
    if current != PIN:
        run([git,"fetch","origin"],cwd=GEN); run([git,"checkout",PIN],cwd=GEN)
    patch_ara_windows_target_paths()
    if not (GEN/"node_modules").exists() or not (GEN/"node_modules/.modules.yaml").exists():
        run_pnpm(["install","--no-frozen-lockfile"],cwd=GEN)
    if not (GEN/"public"/"assets").exists() or not any((GEN/"public"/"assets").iterdir()):
        run([npm,"run","setup-assets"],cwd=GEN)
    elif ara_target_assets_need_rebuild():
        log("Ara target pack or slider catalog is empty; rebuilding public/assets with the Windows path fix.")
        if not (GEN/"vendor"/"mh"/"makehuman"/"data").is_dir() or not (GEN/"vendor"/"sys").is_dir():
            run([npm,"run","setup-assets"],cwd=GEN)
        else:
            run([npm,"run","build-assets"],cwd=GEN)
    if ara_target_assets_need_rebuild():
        fail("Ara asset rebuild completed, but targets.pack or catalog sliders are still empty.")
    patch=ROOT/"tools/ara/patch_layering.py"
    patch_stamp=CACHE/"stamps"/"layering-patch.sha256"
    patch_hash=digest([patch],PIN)
    if not patch_stamp.is_file() or patch_stamp.read_text().strip()!=patch_hash:
        run([py,patch],cwd=GEN)
        patch_stamp.parent.mkdir(parents=True,exist_ok=True); patch_stamp.write_text(patch_hash+"\n")
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
    npc_manifest=ROOT/"data/characters/hollowmere_npcs.json"
    npc_manifest_data=json.loads(npc_manifest.read_text(encoding="utf-8"))
    item_catalog=load_item_catalog()
    validate_character_definitions(npc_manifest_data,item_catalog)
    npc_profiles=npc_manifest_data["characters"]
    wren_profile=next((profile for profile in npc_profiles if profile.get("id")=="wren_talbot"),None)
    if wren_profile is None: fail("Cannot build the Wren Ara body: wren_talbot profile is missing")
    wren_body=dict(body)
    wren_body.update(ara_export_params(wren_profile,item_catalog,include_equipped=False,name="Ara Base Person - Wren Talbot bare body"))
    wren_body.update({
      "name":"Ara Base Person - Wren Talbot bare body",
      "outfit":"none","top":"none","underTop":"none","underBottom":"none",
      "jacket":"none","bottom":"none","underwear":False,"shoes":"none",
      "hat":"none","hair":"none","weapon":"none","carry":"none",
      "accessories":[],"earrings":"none","garmentStyles":{},
      "detail":wren_profile.get("detail","high"),"rig":"game","restPose":"A",
      "animations":True,"faceBones":True,"faceShapes":True,"speechShapes":False,
      "expression":"neutral"
    })
    # A second export uses exactly the same body parameters and rig settings,
    # but includes Wren's current inventory garments. Its clothes are extracted
    # only after the anatomy pass, so their fit and skeleton match her bare body.
    wren_dressed=ara_export_params(wren_profile,item_catalog,include_equipped=True,name="Ara Base Person - Wren Talbot garment source")
    wren_dressed.update({"hair":"none","accessories":[],"earrings":"none"})
    # Diagnostic control: identical Wren garments and body profile, but no footwear.
    # Comparing this export with the booted one isolates Ara's footwear effect.
    wren_dressed_no_shoes=dict(wren_dressed)
    wren_dressed_no_shoes.update({
      "name":"Ara Base Person - Wren Talbot garment source no shoes",
      "shoes":"none"
    })
    # Production generic male: use the same Ara macro system as every other adult,
    # with a modest masculine torso/arm profile expressed as ordinary detail sliders.
    # These are defaults, not hard gender locks; individual character profiles may vary.
    male=dict(body); male.update({
      "name":"Ara Base Person - male body","seed":417,"gender":1,
      "breastSize":0,"breastFirmness":0,
      "modifiers":dict(DEFAULT_MALE_BODY_MODIFIERS)})
    # Deliberately exaggerated comparison pair. These are diagnostic exports only;
    # they are never packaged or used as production character defaults.
    female_test=dict(body); female_test.update({
      "name":"Ara diagnostic - female maximum breast morph","seed":731,
      "gender":0,"breastSize":1.0,"breastFirmness":1.0})
    male_test=dict(body); male_test.update({
      "name":"Ara diagnostic - male minimum breast and broad upper body","seed":947,
      "gender":1,"breastSize":0.0,"breastFirmness":0.0,
      "modifiers":{
        "torso/torso-vshape":0.85,
        "torso/torso-muscle-dorsi":0.75,
        "torso/torso-muscle-pectoral":0.45,
        "armslegs/upperarm-muscle":0.85,
        "armslegs/upperarm-scale-horiz":0.70,
        "armslegs/upperarm-scale-depth":0.65,
        "armslegs/lowerarm-muscle":0.65,
        "armslegs/lowerarm-scale-horiz":0.35
      }})
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
    params={"ara_person_benchmark":base,"ara_person_body":body,"ara_person_male_raw":male,"ara_person_gender_test_female":female_test,"ara_person_gender_test_male":male_test,"ara_person_mobile":mobile,"ara_person_wrapper_knee":dict(body, name="Ara Wrapper Knee Source", bottom="wrapper_knee"),"ara_person_wren_body":wren_body,"ara_person_wren_dressed":wren_dressed,"ara_person_wren_dressed_no_shoes":wren_dressed_no_shoes}
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
        cached("ara-"+key,[glb],[param,patch,ROOT/"tools/character_definitions.py",ROOT/"data/items/item_definitions.json",GEN/"public/assets/targets.pack",GEN/"public/assets/catalog.json"],PIN+":"+str(current),action)
        shutil.copy2(glb,ARA/(key+".glb")); shutil.copy2(param,ARA/(key+".params.json"))
    if options.anatomy_review_only:
        review_root = ROOT / "build" / "anatomy-review"
        review_root.mkdir(parents=True, exist_ok=True)
        female_raw = RAW / "ara_person_body.glb"
        male_raw = RAW / "ara_person_male_raw.glb"
        female_final = review_root / "female_average_vulva.glb"
        female_hybrid = review_root / "female_average_hybrid.glb"
        male_erect = review_root / "male_average_erect.glb"
        male_flaccid = review_root / "male_average_flaccid.glb"
        export("ara_person_body", body)
        export("ara_person_male_raw", male)

        review_env = os.environ.copy()
        review_env.update({"EGL_PLATFORM": "surfaceless", "LIBGL_ALWAYS_SOFTWARE": "1"})
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/blender/add_adult_anatomy.py", "--",
             "--input", female_raw, "--output", female_final, "--profile", "female",
             "--adult", "--deformation-scale", "1.65"], env=review_env)
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/blender/add_adult_anatomy.py", "--",
             "--input", female_raw, "--output", female_hybrid, "--profile", "female",
             "--adult", "--deformation-scale", "1.65", "--method", "hybrid"], env=review_env)

        # Independent review candidate: Claude's integrated surface-following
        # sculpt. It is deliberately separate from female_final and production.
        female_claude = review_root / "female_average_claude_integrated.glb"
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/blender/add_adult_anatomy_claude.py", "--",
             "--input", female_raw, "--output", female_claude, "--profile", "female",
             "--adult", "--method", "integrated", "--deformation-scale", "1.65"], env=review_env)

        # Export Ara's underwear variants against the same average female
        # profile, then assemble them over the accepted integrated-surface body.
        # This is a review-only fit pass: it never replaces the production body.
        underwear_keys = (
            "ara_person_benchmark", "ara_person_halter_bra_lace",
            "ara_person_halter_bra_fishnet", "ara_person_triangle_bikini_top",
            "ara_person_string_bikini_bottom", "ara_person_lace_briefs",
            "ara_person_fishnet_briefs",
        )
        for key in underwear_keys:
            export(key, params[key])

        underwear_assembled = review_root / "female_underwear_all_assembled.glb"
        underwear_fitted = review_root / "female_underwear_all_fitted.glb"
        benchmark_glb = RAW / "ara_person_benchmark.glb"
        lace_bra_glb = RAW / "ara_person_halter_bra_lace.glb"
        fishnet_bra_glb = RAW / "ara_person_halter_bra_fishnet.glb"
        triangle_glb = RAW / "ara_person_triangle_bikini_top.glb"
        string_bottom_glb = RAW / "ara_person_string_bikini_bottom.glb"
        lace_briefs_glb = RAW / "ara_person_lace_briefs.glb"
        fishnet_briefs_glb = RAW / "ara_person_fishnet_briefs.glb"
        assemble_args = [
            py, ROOT / "tools/ara/assemble_modular_glb.py",
            female_claude, underwear_assembled,
            benchmark_glb, "Bra", benchmark_glb, "Briefs",
            lace_bra_glb, "Halter lace bra cups",
            lace_bra_glb, "Halter lace bra piping",
            lace_bra_glb, "Halter lace bra straps",
            fishnet_bra_glb, "Halter fishnet bra cups",
            fishnet_bra_glb, "Halter fishnet bra straps",
            triangle_glb, "Bikini top=Triangle bikini top",
            triangle_glb, "Bikini strings*=Triangle bikini strings",
            string_bottom_glb, "String bikini bottom",
            string_bottom_glb, "String bikini strings",
            lace_briefs_glb, "Lace briefs",
            lace_briefs_glb, "Lace briefs ties",
            fishnet_briefs_glb, "Fishnet briefs",
            fishnet_briefs_glb, "Fishnet briefs ties",
        ]
        run(assemble_args)
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/blender/add_adult_anatomy.py", "--",
             "--input", underwear_assembled, "--output", underwear_fitted,
             "--profile", "none", "--adult", "--fit-existing"], env=review_env)
        underwear_review_dir = review_root / "renders" / "female_underwear"
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/review/render_modular_outfits.py", "--",
             underwear_fitted, underwear_review_dir,
             "skin", "standard_bra", "standard_briefs",
             "lace_bra", "fishnet_bra", "triangle_bra",
             "string_briefs", "lace_briefs", "fishnet_briefs"], env=review_env)

        # The accepted average female integrated body above is the sole body
        # used for this fit pass. Do not generate a second max-breast body:
        # morph behaviour must be tested on this assembled character in a
        # dedicated morph-weight review, not by substituting another base mesh.

        # Use the established character cameras plus blue and natural-colour
        # close-ups. Keep all outputs inside the review artifact.
        claude_review_dir = review_root / "renders" / "female_average_claude_integrated"
        for focus_name, focus_args in (("full", []), ("pelvis", ["--focus-pelvis"])):
            output_dir = claude_review_dir / focus_name
            output_dir.mkdir(parents=True, exist_ok=True)
            run([blender, "--background", "--python-exit-code", "1", "--python",
                 ROOT / "tools/blender/inspect_character.py", "--",
                 "--input", female_claude, "--output-dir", output_dir,
                 "--frame", "1", *focus_args], env=review_env)
        claude_detail_dir = claude_review_dir / "pelvis_detail"
        claude_detail_dir.mkdir(parents=True, exist_ok=True)
        anatomy_review = ROOT / "tools" / "blender" / "review_anatomy_closeup.py"
        run([blender, "--background", "--python-exit-code", "1", "--python",
             anatomy_review, "--", "--input", female_claude, "--output-dir", claude_detail_dir,
             "--label", "female_average_claude_integrated"], env=review_env)
        run([blender, "--background", "--python-exit-code", "1", "--python",
             anatomy_review, "--", "--input", female_claude, "--output-dir", claude_detail_dir,
             "--label", "female_average_claude_integrated", "--natural-colour"], env=review_env)
        for pose_name, pose_output in (("erect", male_erect), ("flaccid", male_flaccid)):
            run([blender, "--background", "--python-exit-code", "1", "--python",
                 ROOT / "tools/blender/add_male_anatomy.py", "--",
                 "--input", male_raw, "--output", pose_output, "--adult",
                 "--profile-name", "male_average", "--anatomy-state", pose_name], env=review_env)

        # New comparison: one unchanged erect basis mesh with a real flaccid
        # shape key, animated together with the existing anatomy bone chain.
        male_morph_pose = review_root / "male_average_morph_pose.glb"
        male_morph_dir = review_root / "male_morph_pose"
        male_morph_dir.mkdir(parents=True, exist_ok=True)
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/blender/test_male_morph_pose.py", "--",
             "--input", male_erect, "--output", male_morph_pose,
             "--review-dir", male_morph_dir], env=review_env)

        # New standalone high-resolution sculpt prototype, conformed to the
        # raw Ara female pelvis. It is deliberately not integrated into the
        # production body or clothing pipeline.
        female_sculpt = review_root / "female_vulva_highres_sculpt.glb"
        female_sculpt_dir = review_root / "female_vulva_sculpt"
        female_sculpt_dir.mkdir(parents=True, exist_ok=True)
        run([blender, "--background", "--python-exit-code", "1", "--python",
             ROOT / "tools/blender/build_female_vulva_sculpt.py", "--",
             "--input", female_raw, "--output", female_sculpt,
             "--review-dir", female_sculpt_dir, "--resolution", "160"], env=review_env)

        shutil.copy2(female_raw, review_root / "female_average_raw.glb")
        shutil.copy2(male_raw, review_root / "male_average_raw.glb")
        review_models = (
            ("female_average", female_final, "female", 1),
            ("female_average_hybrid", female_hybrid, "female", 1),
            ("male_average_erect", male_erect, "male", 1),
            ("male_average_flaccid", male_flaccid, "male", 24),
        )
        for label, model, _kind, frame in review_models:
            for focus_name, focus_args in (("full", []), ("pelvis", ["--focus-pelvis"])):
                output_dir = review_root / "renders" / label / focus_name
                output_dir.mkdir(parents=True, exist_ok=True)
                run([blender, "--background", "--python-exit-code", "1", "--python",
                     ROOT / "tools/blender/inspect_character.py", "--",
                     "--input", model, "--output-dir", output_dir, "--frame", str(frame),
                     *focus_args], env=review_env)

        # Render blue diagnostic and natural-colour close-ups from the exact
        # average-body GLBs above. Keep them inside build/anatomy-review so the
        # workflow artifact always contains the images used for approval.
        anatomy_review = ROOT / "tools" / "blender" / "review_anatomy_closeup.py"
        closeup_reports = {}
        for label, model in (("female_average", female_final),
                             ("female_average_hybrid", female_hybrid),
                             ("male_average_erect", male_erect),
                             ("male_average_flaccid", male_flaccid)):
            closeup_dir = review_root / "renders" / label / "pelvis_detail"
            closeup_dir.mkdir(parents=True, exist_ok=True)
            run([blender, "--background", "--python-exit-code", "1", "--python",
                 anatomy_review, "--", "--input", model, "--output-dir", closeup_dir,
                 "--label", label], env=review_env)
            run([blender, "--background", "--python-exit-code", "1", "--python",
                 anatomy_review, "--", "--input", model, "--output-dir", closeup_dir,
                 "--label", label, "--natural-colour"], env=review_env)
            closeup_reports[label] = str((closeup_dir / (label + "_anatomy_review.json")).relative_to(review_root))

        report = {
            "schema_version": 1,
            "purpose": "visual anatomy prototype only; not production-approved",
            "ara_generator_commit": PIN,
            "profiles": ["female_average", "female_average_hybrid", "female_average_claude_integrated", "male_average_erect", "male_average_flaccid"],
            "female": {
                "asset": female_final.name,
                "claude_integrated_review_candidate": female_claude.name,
                "hybrid_comparison_asset": female_hybrid.name,
                "hybrid_method": "integrated skin sculpt plus buried surface-sampled, pelvis-weighted lofts sharing Ara skin material",
                "deformation_scale": 1.65,
                "targets_percent_of_body_height": {
                    "mons_pubis_fullness": 0.50,
                    "labia_majora_relief": 0.375,
                    "labia_minora_relief": 0.25,
                    "clitoral_hood_relief": 0.225,
                    "vestibular_recess": 0.1875
                },
                "pigmentation": "skin-relative vertex colour; stronger inner/central contrast"
            },
            "male": {
                "assets": [male_erect.name, male_flaccid.name],
                "anatomy_states": ["erect", "flaccid"],
                "shared_mesh": True,
                "dedicated_bones": ["AnatomyRoot", "AnatomyMid", "AnatomyTip"],
                "animation": "MaleAnatomy_ErectToFlaccid"
            },
            "views": ["front", "side", "rear", "three_quarter"],
            "male_pose_frames": {"erect": 1, "flaccid": 24},
            "detail_review": {
                "source_models": "same average-body GLBs listed in profiles",
                "render_modes": ["blue diagnostic", "natural colour"],
                "reports": closeup_reports
            },
            "review_note": "Inspect raw and processed GLBs, standard full/pelvis renders, and blue/natural-colour pelvis detail renders under the same lighting."
        }
        (review_root / "anatomy_review_report.json").write_text(
            json.dumps(report, indent=2) + "\\n", encoding="utf-8"
        )
        log(f"Anatomy-only review build complete: {review_root}")
        return

    for key,p in params.items(): export(key,p)
    # Anatomy integration: female base and male base, cached separately.
    female_out=ARA/"ara_person_body.glb"; female_raw=RAW/"ara_person_body.glb"
    # Use generated raw body as input; retain a distinct output so cache is safe.
    def female():
        env=os.environ.copy(); env.update({"ARA_INPUT":str(female_raw),"ARA_OUTPUT":str(RAW/"ara_person_body_anatomy.glb"),"ARA_PROFILE":"female","ARA_ADULT":"1"})
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py"],env=env)
        shutil.copy2(RAW/"ara_person_body_anatomy.glb",female_out)
    cached("female-anatomy",[female_out],[female_raw,ROOT/"tools/blender/add_adult_anatomy.py"],"female-anatomy-v2:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],female)
    # Wren's body is generated by Ara from her own profile parameters. Ara's
    # macro body controls are baked into the mesh at export; only facial shapes
    # remain as runtime blend shapes. Keep this bare body separate from inventory.
    wren_raw=RAW/"ara_person_wren_body.glb"; wren_out=ARA/"ara_person_wren_body.glb"
    def build_wren_body():
        env=os.environ.copy(); env.update({"ARA_INPUT":str(wren_raw),"ARA_OUTPUT":str(RAW/"ara_person_wren_body_anatomy.glb"),"ARA_PROFILE":"female","ARA_ADULT":"1"})
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py"],env=env)
        shutil.copy2(RAW/"ara_person_wren_body_anatomy.glb",wren_out)
    cached("wren-female-anatomy",[wren_out],[wren_raw,ROOT/"tools/blender/add_adult_anatomy.py"],"wren-female-anatomy-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],build_wren_body)
    wren_dressed_raw=RAW/"ara_person_wren_dressed.glb"
    wren_dressed_out=ARA/"ara_person_wren_dressed.glb"
    def build_wren_dressed():
        env=os.environ.copy(); env.update({"ARA_INPUT":str(wren_dressed_raw),"ARA_OUTPUT":str(RAW/"ara_person_wren_dressed_anatomy.glb"),"ARA_PROFILE":"female","ARA_ADULT":"1"})
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py"],env=env)
        shutil.copy2(RAW/"ara_person_wren_dressed_anatomy.glb",wren_dressed_out)
    cached("wren-dressed-anatomy",[wren_dressed_out],[wren_dressed_raw,ROOT/"tools/blender/add_adult_anatomy.py"],"wren-dressed-anatomy-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],build_wren_dressed)
    # Build the same Wren garment source without shoes as a controlled test.
    # Both dressed variants receive the identical adult anatomy pass.
    wren_no_shoes_raw=RAW/"ara_person_wren_dressed_no_shoes.glb"
    wren_no_shoes_out=ARA/"ara_person_wren_dressed_no_shoes.glb"
    def build_wren_no_shoes():
        env=os.environ.copy(); env.update({"ARA_INPUT":str(wren_no_shoes_raw),"ARA_OUTPUT":str(RAW/"ara_person_wren_dressed_no_shoes_anatomy.glb"),"ARA_PROFILE":"female","ARA_ADULT":"1"})
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py"],env=env)
        shutil.copy2(RAW/"ara_person_wren_dressed_no_shoes_anatomy.glb",wren_no_shoes_out)
    cached("wren-dressed-no-shoes-anatomy",[wren_no_shoes_out],[wren_no_shoes_raw,ROOT/"tools/blender/add_adult_anatomy.py"],"wren-dressed-no-shoes-anatomy-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],build_wren_no_shoes)

    # The no-shoes export is now the canonical Wren garment source: the
    # controlled comparison proved its complete rest rig matches the bare body.
    # Keep the booted export only as a diagnostic/reference output; never use it
    # as the source for skinned garments because Ara shifts its Hips by 30.4mm.
    footwear_report=ARA/"ara_person_wren_footwear_rig_comparison.json"
    footwear_test=ROOT/"tools/blender/compare_ara_footwear_rigs.py"
    def compare_footwear_rigs():
        run([blender,"--background","--python-exit-code","1","--python",footwear_test,"--",
          "--reference",wren_out,"--no-shoes",wren_no_shoes_out,
          "--with-shoes",wren_dressed_out,"--report",footwear_report])
    cached("compare-wren-footwear-rigs",[footwear_report],
      [wren_out,wren_no_shoes_out,wren_dressed_out,footwear_test],
      "read-only-footwear-rig-comparison-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
      compare_footwear_rigs)
    log("Footwear comparison complete. No-shoes export matches the bare-body rest rig; using it as the garment source.")
    wren_garment_source=wren_no_shoes_out

    wren_validation=ARA/"ara_person_wren_body.validation.json"
    def validate_wren_body():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/validate_ara_body_variant.py","--","--reference",wren_out,"--candidate",wren_garment_source,"--output",wren_validation])
    cached("validate-wren-body",[wren_validation],[wren_out,wren_garment_source,ROOT/"tools/blender/validate_ara_body_variant.py"],"no-shoes-canonical-rest-rig-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],validate_wren_body)
    # Anatomy-processed diagnostic pair, kept outside the runtime package.
    female_test_raw=RAW/"ara_person_gender_test_female.glb"
    female_test_out=ARA/"ara_person_gender_test_female.glb"
    def female_test_action():
        env=os.environ.copy(); env.update({"ARA_INPUT":str(female_test_raw),"ARA_OUTPUT":str(RAW/"ara_person_gender_test_female_anatomy.glb"),"ARA_PROFILE":"female","ARA_ADULT":"1"})
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py"],env=env)
        shutil.copy2(RAW/"ara_person_gender_test_female_anatomy.glb",female_test_out)
    cached("gender-test-female-anatomy",[female_test_out],[female_test_raw,ROOT/"tools/blender/add_adult_anatomy.py"],"max-breast-diagnostic-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],female_test_action)

    male_test_raw=RAW/"ara_person_gender_test_male.glb"
    male_test_out=ARA/"ara_person_gender_test_male.glb"
    def male_test_action():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_male_anatomy.py","--","--input",male_test_raw,"--output",male_test_out,"--adult","--profile-name","diagnostic_broad_male"])
    cached("gender-test-male-anatomy",[male_test_out],[male_test_raw,ROOT/"tools/blender/add_male_anatomy.py"],"minimum-breast-broad-shoulder-diagnostic-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],male_test_action)

    male_out=ARA/"ara_person_male_body.glb"; male_raw=RAW/"ara_person_male_raw.glb"
    def male_action():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_male_anatomy.py","--","--input",male_raw,"--output",male_out,"--adult","--profile-name","standard","--anatomy-state","flaccid"])
    cached("male-anatomy-flaccid",[male_out],[male_raw,ROOT/"tools/blender/add_male_anatomy.py"],"male-anatomy-shared-rig-v2:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],male_action)

    # Preserve the previous protruding design as a separate optional reference;
    # it is never used by the default male body or garment-fitting pipeline.
    male_erect_reference=ARA/"ara_person_male_erect_reference.glb"
    def male_erect_reference_action():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_male_anatomy.py","--","--input",male_raw,"--output",male_erect_reference,"--adult","--profile-name","standard","--anatomy-state","erect"])
    cached("male-anatomy-erect",[male_erect_reference],[male_raw,ROOT/"tools/blender/add_male_anatomy.py"],"male-anatomy-erect-v2-rigged:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],male_erect_reference_action)
    # Read-only audit: run the exact production deformation functions on raw exports,
    # measure vertex movement in memory, then verify the meshes survive GLB round-trip.
    anatomy_pipeline_audit=ARA/"ara_person_anatomy_pipeline_audit.json"
    anatomy_audit_script=ROOT/"tools/blender/audit_anatomy_pipeline.py"
    def audit_anatomy_pipeline():
        run([blender,"--background","--python-exit-code","1","--python",anatomy_audit_script,"--",
          "--female-raw",female_raw,"--male-raw",male_raw,
          "--work-dir",RAW/"anatomy_pipeline_audit",
          "--female-script",ROOT/"tools/blender/add_adult_anatomy.py",
          "--male-script",ROOT/"tools/blender/add_male_anatomy.py",
          "--output",anatomy_pipeline_audit])
    cached("audit-anatomy-pipeline",[anatomy_pipeline_audit],
      [female_raw,male_raw,anatomy_audit_script,
       ROOT/"tools/blender/add_adult_anatomy.py",ROOT/"tools/blender/add_male_anatomy.py"],
      "exact-deformation-and-glb-roundtrip-audit-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
      audit_anatomy_pipeline)
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
    fitted_under=RAW/"ara_person_modular_underwear_fitted.glb"
    def fit():
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_dress_slit.py","--","--input",modular,"--output",RAW/"slit.glb"],env=env)
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py","--","--input",RAW/"slit.glb","--output",fitted,"--profile","none","--adult","--fit-existing"],env=env)
        run([blender,"--background","--python-exit-code","1","--python",ROOT/"tools/blender/add_adult_anatomy.py","--","--input",underwear,"--output",fitted_under,"--profile","none","--adult","--fit-existing"],env=env)
    cached("garment-fit",[fitted,fitted_under],
      [modular,underwear,ROOT/"tools/blender/add_dress_slit.py",ROOT/"tools/blender/add_adult_anatomy.py"],
      "separate-fitted-outputs-v2:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
      fit)
    # Convert combined Ara/NPC clothing surfaces into independently skinned
    # garment objects. This is local Blender work, never a GitHub Actions job.
    garments=RAW/"ara_person_garments.glb"
    garment_builder=ROOT/"tools/blender/build_ara_garment_library.py"
    garment_report=garments.with_suffix(".report.json")
    def build_garment_library():
        run([blender,"--background","--python-exit-code","1","--python",garment_builder,
          "--","--base-body",wren_out,"--profile-source",wren_garment_source,
          "--npc-manifest",npc_manifest,"--profile-id","wren_talbot","--output",garments])
        if not garment_report.is_file():
            fail("Garment builder completed without its skinning validation report.")
    cached("garment-library",[garments,garment_report],
      [wren_out,wren_garment_source,npc_manifest,garment_builder],
      "garment-library-v5-no-shoes-canonical-skeleton:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
      build_garment_library)

    # Compare the raw Ara exports before anatomy processing. This isolates
    # generator gender morph failures from Blender anatomy integration.
    gender_report=ARA/"ara_person_gender_anatomy_validation.json"
    gender_validator=ROOT/"tools/blender/validate_ara_gender_variants.py"
    def validate_gender_variants():
        run([blender,"--background","--python-exit-code","1","--python",gender_validator,"--",
          "--female-raw",RAW/"ara_person_body.glb",
          "--male-raw",male_raw,
          "--female-final",female_out,
          "--male-final",male_out,
          "--female-test-raw",female_test_raw,
          "--male-test-raw",male_test_raw,
          "--female-test-final",female_test_out,
          "--male-test-final",male_test_out,
          "--output",gender_report])
    cached("validate-gender-anatomy",[gender_report],
      [RAW/"ara_person_body.glb",male_raw,female_out,male_out,
       female_test_raw,male_test_raw,female_test_out,male_test_out,gender_validator],
      "gender-anatomy-diagnostics-v1:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
      validate_gender_variants)

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
    # Keep raw, pre-anatomy views beside final views. If these already look
    # alike, the problem is upstream in Ara generation rather than Blender.
    review_character("female-body-raw",RAW/"ara_person_body.glb","body_raw")
    review_character("male-body-raw",male_raw,"male_raw")
    review_character("female-body",female_out,"body")
    review_character("wren-body",wren_out,"wren_body")
    review_character("wren-dressed",wren_dressed_out,"wren_dressed")
    review_character("male-body-flaccid",male_out,"male_flaccid")
    review_character("male-body-erect",male_erect_reference,"male_erect_reference")
    review_character("gender-test-female",female_test_out,"gender_test_female")
    review_character("gender-test-male",male_test_out,"gender_test_male")
    # Dedicated pelvis close-ups use temporary blue material highlighting.
    # These review-only renders are never copied into the runtime package.
    anatomy_review=ROOT/"tools/blender/review_anatomy_closeup.py"
    for label,model in [("female_max_breast",female_test_out),("male_min_breast_broad",male_test_out)]:
        review_dir=review_root/"anatomy"/label
        review_outputs=[review_dir/f"{label}_{view}_blue.png" for view in ["front","three_quarter"]]+[review_dir/f"{label}_{view}_natural.png" for view in ["front","three_quarter"]]+[review_dir/f"{label}_anatomy_review.json"]
        def anatomy_review_action(label=label,model=model,review_dir=review_dir):
            review_dir.mkdir(parents=True,exist_ok=True)
            run([blender,"--background","--python-exit-code","1","--python",anatomy_review,
              "--","--input",model,"--output-dir",review_dir,"--label",label],env=review_env)
            run([blender,"--background","--python-exit-code","1","--python",anatomy_review,
              "--","--input",model,"--output-dir",review_dir,"--label",label,"--natural-colour"],env=review_env)
        cached("review-anatomy-"+label,review_outputs,[model,anatomy_review],
          "blue-and-natural-pelvis-closeup-review-v3-shader-validation:blender:"+subprocess.check_output([blender,"--version"],text=True).splitlines()[0],
          anatomy_review_action)

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
        "ara_person_modular.glb": fitted,
        "ara_person_modular_underwear.glb": fitted_under,
        "ara_person_male_body.glb": ARA/"ara_person_male_body.glb",
        "reference/male_erect_reference.glb": male_erect_reference,
        "ara_person_garments.glb": garments,
        "bodies/wren_talbot.glb": wren_out,
    }
    names=list(sources)
    def pack():
        package.mkdir(parents=True,exist_ok=True)
        for name,source in sources.items():
            if not source.is_file():
                fail(f"Runtime package source missing: {source}")
            destination=package/name
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,destination)
        assets={}
        for name in names:
            b=(package/name).read_bytes(); assets[name]={"size_bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
        manifest={"schema_version":1,"package_version":"local-"+digest(list(sources.values()))[:16],"source_commit":current,"generator":{"repository":"https://github.com/olatunde85/3d-gen","commit":PIN},"assets":assets}
        (package/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    cached("runtime-package",[package/"manifest.json"]+[package/n for n in names],
      list(sources.values())+[ROOT/"tools/build_ara_runtime_local.py"],
      "runtime-package-v3-with-builder-provenance",pack)
    log("Ara + Blender runtime assets ready. Cached stages will be skipped on the next run.")

if __name__=="__main__":
    main()
