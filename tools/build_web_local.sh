#!/usr/bin/env bash
# Local Silverhart Saga web build for Git Bash on Windows (also works on macOS/Linux).
# Never pulls, switches branches, stages files, or changes Git history.
set -Eeuo pipefail

REPO="ScottENOC/Silverhart-Saga-3D"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PYTHON_BIN=python
GODOT_BIN="\${GODOT_BIN:-godot}"

log()  { printf '\n[Silverhart] %s\n' "$*"; }
warn() { printf '\n[Warning] %s\n' "$*" >&2; }
die()  { printf '\n[Error] %s\n' "$*" >&2; exit 1; }

for cmd in git gh ffmpeg unzip; do command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"; done
command -v "$PYTHON_BIN" >/dev/null 2>&1 || die "Python was not found (expected 'python')."
command -v "$GODOT_BIN" >/dev/null 2>&1 || die "Godot was not found. Set GODOT_BIN to the full path of the Godot 4.7.2 console executable."
[[ "$(git branch --show-current)" == dev ]] || die "This script only builds from dev. It will not switch branches."
GODOT_VERSION="$("$GODOT_BIN" --version 2>&1 | head -n 1)"
[[ "$GODOT_VERSION" == 4.7.2* ]] || die "Expected Godot 4.7.2; found $GODOT_VERSION."
gh auth status >/dev/null 2>&1 || die "GitHub CLI is not authenticated. Run 'gh auth login' first."

if [[ -n "$(git status --porcelain)" ]]; then
  warn "Local changes will be included in this build; nothing will be staged or committed."
  git status --short
fi

CACHE="$ROOT/build/local-cache"
mkdir -p "$CACHE" "$ROOT/art/characters/hollowmere" "$ROOT/art/characters/ara_runtime/props"

latest_success() {
  gh api "repos/$REPO/actions/workflows/$1/runs?branch=dev&status=success&per_page=1" --jq '.workflow_runs[0].id // empty'
}
latest_artifact_prefix() {
  local workflow="$1" prefix="$2" run name runs
  runs="$(gh api "repos/$REPO/actions/workflows/$workflow/runs?branch=dev&per_page=10" --jq '.workflow_runs[].id')"
  while IFS= read -r run; do
    [[ -n "$run" ]] || continue
    name="$(gh api "repos/$REPO/actions/runs/$run/artifacts" --jq ".artifacts[] | select(.expired == false) | select(.name | startswith(\"$prefix\")) | .name" | head -n 1 || true)"
    if [[ -n "$name" ]]; then printf '%s|%s\n' "$run" "$name"; return 0; fi
  done <<< "$runs"
  return 1
}
download_artifact() {
  rm -rf "$3"
  mkdir -p "$3"
  gh run download "$1" --repo "$REPO" --name "$2" --dir "$3"
}

log "Checking Hollowmere character models"
ARA_RUN="$(latest_success hollowmere-npcs.yml)"
[[ -n "$ARA_RUN" ]] || die "No successful Hollowmere Ara character run exists on dev."
ARA_NAME="$(gh api "repos/$REPO/actions/runs/$ARA_RUN/artifacts" --jq '.artifacts[] | select(.name == "hollowmere-npc-models" and .expired == false) | .name' | head -n 1)"
[[ -n "$ARA_NAME" ]] || die "The latest successful Hollowmere run has no unexpired NPC model artifact. Re-run Build Hollowmere Ara characters on dev."
if [[ ! -f "$CACHE/hollowmere.run" || "$(cat "$CACHE/hollowmere.run")" != "$ARA_RUN" || ! -s art/characters/hollowmere/profiles.json ]]; then
  log "Downloading NPC pack from Actions run $ARA_RUN"
  download_artifact "$ARA_RUN" "$ARA_NAME" "$CACHE/hollowmere"
  cp -a "$CACHE/hollowmere/." art/characters/hollowmere/
  printf '%s' "$ARA_RUN" > "$CACHE/hollowmere.run"
else
  log "NPC pack already cached (run $ARA_RUN)"
fi

log "Checking Wren Workshop runtime package"
WORKSHOP="$(latest_artifact_prefix wren-workshop.yml ara-runtime-assets-)" || die "No unexpired Workshop runtime package in the latest ten runs. Run Build Wren Workshop on dev."
WORKSHOP_RUN="\${WORKSHOP%%|*}"
WORKSHOP_NAME="\${WORKSHOP#*|}"
if [[ ! -f "$CACHE/workshop.run" || "$(cat "$CACHE/workshop.run")" != "$WORKSHOP_RUN" || ! -s art/characters/ara_runtime/ara_person_modular.glb ]]; then
  log "Downloading Workshop package from run $WORKSHOP_RUN"
  download_artifact "$WORKSHOP_RUN" "$WORKSHOP_NAME" "$CACHE/workshop"
  PACKAGE="$(find "$CACHE/workshop" -type f -name ara-runtime-assets.zip -print -quit)"
  [[ -n "$PACKAGE" ]] || die "Workshop artifact did not contain ara-runtime-assets.zip."
  unzip -o -q "$PACKAGE" -d art/characters/ara_runtime
  printf '%s' "$WORKSHOP_RUN" > "$CACHE/workshop.run"
else
  log "Workshop package already cached (run $WORKSHOP_RUN)"
fi

download_optional_props() {
  local workflow="$1" prefix="$2" marker="$3" label="$4" run name
  run="$(latest_success "$workflow")"
  if [[ -z "$run" ]]; then warn "No successful $label build found; continuing without that optional bundle."; return; fi
  name="$(gh api "repos/$REPO/actions/runs/$run/artifacts" --jq ".artifacts[] | select(.expired == false) | select(.name | startswith(\"$prefix\")) | .name" | head -n 1 || true)"
  if [[ -z "$name" ]]; then warn "No unexpired $label artifact; continuing without it."; return; fi
  if [[ -f "$CACHE/$marker.run" && "$(cat "$CACHE/$marker.run")" == "$run" ]]; then
    log "$label already cached (run $run)"
    return
  fi
  log "Downloading $label from run $run"
  download_artifact "$run" "$name" "$CACHE/$marker"
  find "$CACHE/$marker" -type f -name '*.glb' -exec cp -f '{}' art/characters/ara_runtime/props/ \;
  printf '%s' "$run" > "$CACHE/$marker.run"
}
download_optional_props ara-medieval-props.yml ara-medieval-props- weapons weapons
download_optional_props ara-medieval-armour-props.yml ara-medieval-armour-props- armour armour

log "Fetching pinned Kenney nature models if missing"
if [[ ! -s art/environment/kenney_nature/tree_oak.glb || ! -s art/environment/kenney_nature/LICENSE.txt ]]; then
  "$PYTHON_BIN" tools/ci/fetch_kenney_nature_assets.py
else
  log "Kenney nature assets already present"
fi

log "Importing legacy audio if required"
if [[ ! -s audio/legacy/title.ogg || ! -s audio/legacy/dialogue/arena_entrance.ogg || ! -s audio/legacy/effects/parry.ogg ]]; then
  "$PYTHON_BIN" tools/import_legacy_audio.py
else
  log "Legacy Ogg audio already present"
fi

log "Validating the 14 generated NPC/player models"
"$PYTHON_BIN" tools/ci/validate_hollowmere_models.py

log "Importing Godot resources ($GODOT_VERSION)"
"$GODOT_BIN" --headless --editor --path "$ROOT" --quit

log "Running Godot character import validation"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tools/ci/validate_hollowmere_models.gd

log "Running Ara body/clothing/equipment smoke test"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_ara_runtime_equipment.gd

VERSION="local-$(date +%Y%m%d-%H%M%S)"
OUTPUT="$ROOT/build/web"
mkdir -p "$OUTPUT"
log "Exporting Web build to build/web"
"$GODOT_BIN" --headless --path "$ROOT" --export-release Web "$OUTPUT/index.html"
[[ -s "$OUTPUT/index.html" ]] || die "Web export did not produce index.html."
find "$OUTPUT" -maxdepth 1 -type f -name '*.wasm' -print -quit | grep -q . || die "WebAssembly output is missing."
find "$OUTPUT" -maxdepth 1 -type f -name '*.pck' -print -quit | grep -q . || die "Godot PCK output is missing."

printf '%s\n' "$VERSION" > "$OUTPUT/build-version.txt"
"$PYTHON_BIN" tools/pwa/package_godot_pwa.py --directory "$OUTPUT" --version "$VERSION"
"$PYTHON_BIN" -m py_compile tools/pwa/package_godot_pwa.py

log "Verifying PWA package"
"$PYTHON_BIN" - "$OUTPUT" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
manifest = json.loads((root / "index.manifest.json").read_text(encoding="utf-8"))
assert manifest["start_url"] == "./index.html"
assert manifest["scope"] == "./"
assert manifest["display"] == "standalone"
assert manifest["name"] == "Silverhart Saga"
required = ("index.service.worker.js", "index.apple-touch-icon.png", "index.144x144.png",
            "index.180x180.png", "index.512x512.png", "index.wasm", "index.pck", "build-version.txt")
for name in required:
    path = root / name
    assert path.is_file() and path.stat().st_size > 0, f"Missing/empty: {name}"
for name in ("index.apple-touch-icon.png", "index.144x144.png", "index.180x180.png", "index.512x512.png"):
    assert (root / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), f"Invalid PNG: {name}"
worker = (root / "index.service.worker.js").read_text(encoding="utf-8")
assert "ENSURE_CROSSORIGIN_ISOLATION_HEADERS" in worker
html = (root / "index.html").read_text(encoding="utf-8")
assert 'rel="manifest"' in html and "index.service.worker.js" in html and "silverhart-update-now" in html
assert not (root / "service-worker.js").exists()
print("Godot native PWA package verified.")
PY

log "BUILD COMPLETE"
printf 'Output: %s\n' "$OUTPUT"
printf '\nTo preview on this PC, run in another Git Bash window:\n'
printf '  cd "%s"\n  python -m http.server 8000 --directory "%s"\n' "$ROOT" "$OUTPUT"
printf 'Then open http://127.0.0.1:8000/ in your browser.\n'
