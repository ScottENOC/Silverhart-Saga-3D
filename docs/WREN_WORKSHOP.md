# Wren Workshop

The Wren Workshop is a standalone browser-based model inspection tool, separate from the Godot game. It is published to a **private Hugging Face Static Space**. The GitHub source repository is public; the Hugging Face Space remains private.

## Cloud workflow

The GitHub Actions workflow `.github/workflows/wren-workshop.yml` installs Blender from the Ubuntu runner's package repository (Blender 5.0.1 was installed by the runner during the November 6, 2026 build), generates a generic Ara base person and modular garment exports, assembles the viewer site and uploads it to the configured private Hugging Face Space.

It runs manually through Actions → Build Wren Workshop → Run workflow, and automatically when Ara/Blender tools, viewer files or the workflow itself change on `dev` or `feature/shared-character-system`.

The workflow uses standard GitHub-hosted Ubuntu runners. Because this repository is public, standard GitHub-hosted runner minutes are free. Build artifacts and Actions logs are visible to people who can access this public repository.

## One-time setup

1. Create a free account at https://huggingface.co/ if you do not already have one.
2. Create a new **Space**. Choose **Static** as the SDK and set **Visibility** to **Private**. Do not choose Gradio or Docker.
3. In the GitHub repository, open Settings → Secrets and variables → Actions → Variables and add:
   - Name: `HF_SPACE_ID`
   - Value: your Hugging Face Space ID, exactly `your-huggingface-username/wren-workshop`
4. In GitHub, open Settings → Secrets and variables → Actions → Secrets and add:
   - Name: `HF_ADMIN_TOKEN`
   - Value: a Hugging Face access token with write access to the target Space.
5. In GitHub, open Actions → Build Wren Workshop → Run workflow, select the desired branch, and run it.

### Authentication note

The current workflow uses the `HF_ADMIN_TOKEN` GitHub Actions secret. It does **not** currently use Hugging Face Trusted Publisher / OIDC authentication, despite earlier documentation describing that intended setup. The token is not stored in the repository source, but anyone with repository access can see workflow definitions and public build logs. Prefer a narrowly scoped Hugging Face token while this workflow uses a long-lived secret. Migrating to Trusted Publisher OIDC requires configuring the Space to trust the exact repository, branch and workflow, then changing the workflow and removing the secret.

## Viewer controls

- Drag: orbit; pinch or wheel: zoom; two-finger drag: pan.
- Front, back, left, right, three-quarter and reset camera presets.
- Key/fill light intensity and key-light direction.
- Toggle hair, garments/armour, weapon, body hair, tattoo and piercings by mesh-name prefix.

The viewer loads the full character GLB and toggles mesh visibility. It is an inspection tool, not a full material editor or Godot substitute.

## Build outputs

- Intermediate generated-model and integrated-model artifacts are retained for 2 days so dependent jobs can assemble and publish them.
- The final `character-pipeline-evaluation` artifact contains generated models, parameters and review renders and is retained for 14 days.
- These artifacts are visible to repository readers because the GitHub repository is public.
- The viewer and generated full model are uploaded to the private Hugging Face Space. Generated files are not committed back into the source repository.
