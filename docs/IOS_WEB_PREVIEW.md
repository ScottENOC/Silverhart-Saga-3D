# iPhone development preview

## Purpose

The web export is a fast testing target while the polished native iOS application
remains the long-term release target. It is not a second game implementation:
the Godot project remains the only source of truth.

## Branch and deployment rules

- Work on isolated `feature/*` branches.
- Merge reviewed work into `dev`.
- A successful push to `dev` builds and publishes the private iPhone preview.
- `main` remains the stable release branch.
- This workflow does not publish from feature branches or pull requests.
- Do not modify, reset, or reuse the Wren Workshop Space for the game.

## Hugging Face hosting

The game uses a dedicated private Static Space:

`Thisisausername836/silverhart-saga-3d`

The deployment script creates it as private if it does not exist. It refuses to
publish if the Space is public. The existing `HF_ADMIN_TOKEN` GitHub Actions
secret is used; the Wren Workshop `HF_SPACE_ID` variable is deliberately not
read or changed.

If `HF_ADMIN_TOKEN` is absent, the build still runs and is retained as a
GitHub Actions artifact, but it is not published.

## iPhone use

Open the private Space in Safari while signed into Hugging Face. Once the game
has loaded, use Safari's Share menu and choose Add to Home Screen.

Godot's Progressive Web App export support provides an offline cache after the
first successful load. Safari may evict website data when storage is under
pressure, so this is a development convenience rather than a substitute for
native application installation.

## Renderer and web constraints

Godot 4 web exports use WebGL 2.0 and the Compatibility renderer. Forward+ and
Mobile renderers are not supported by the web platform. Godot's web renderer
default is Compatibility; native desktop and iOS export settings remain
independent.

The export uses the single-threaded web runtime for broad browser compatibility,
including iOS Safari.

## Incremental update roadmap

The first deployment stage exports a PWA and writes a SHA-256 build manifest.
This allows us to measure exactly which exported files change between builds.
The PWA can retain unchanged engine files and previously downloaded resources.

A Godot export normally places project resources in one main `index.pck`.
Changing a resource inside that pack changes the pack as a whole, so browser
caching alone does not yet provide true small-file patches.

The next stage is a runtime PCK patch manager:
1. Keep the first full `index.pck` as the base pack.
2. Generate subsequent PCK patches against that exact base and all preceding
   patches using Godot's `--export-patch` and `--patches` options.
3. Download new patches into persistent `user://` storage.
4. Verify SHA-256 before accepting a patch.
5. Load cached patches in order before the game scene starts.
6. Reload only after the new patch set is fully downloaded.
7. Periodically roll the patch chain into a new base pack.

That runtime integration is intentionally a separate change: the active audio
work also changes `project.godot` startup/autoload configuration. We should
combine those startup changes deliberately rather than create duplicate
autoload sections or overwrite another instance's main-scene selection.

## Validation

The workflow imports the project, runs the existing headless simulation tests,
exports the Web preset, checks the required files, and retains the complete
export as a 14-day build artifact. Deployment happens only from `dev`.
