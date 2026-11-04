# Wren Workshop

The Wren Workshop is a standalone browser-based model inspection tool, separate from the Godot game. It is published to a **private Hugging Face Static Space**; the game repository remains private on GitHub.

## Cloud workflow

The GitHub Actions workflow `.github/workflows/wren-workshop.yml` runs Blender 5.2.3 on an Ubuntu runner, generates Wren, exports GLB files, assembles the viewer site and uploads it to the configured private Hugging Face Space.

It runs manually through Actions → Build Wren Workshop → Run workflow, and automatically when Blender generator or viewer files change on `dev`.

## One-time setup

1. Create a free account at https://huggingface.co/ if you do not already have one.
2. Create a new **Space**. Choose **Static** as the SDK and set **Visibility** to **Private**. Give it a simple name such as `wren-workshop`. Do not choose Gradio or Docker.
3. On the Space's Settings page, find **Trusted Publishers** and add a publisher:
   - Provider: GitHub Actions
   - Repository: `ScottENOC/Silverhart-Saga-3D`
   - Branch: `dev`
   - Workflow: `wren-workshop.yml`
4. In the GitHub repository, open Settings → Secrets and variables → Actions → Variables and add:
   - Name: `HF_SPACE_ID`
   - Value: your Hugging Face Space ID, exactly `your-huggingface-username/wren-workshop`
5. In GitHub, open Actions → Build Wren Workshop → Run workflow, select `dev`, and run it.

The Trusted Publisher setup uses GitHub's OIDC identity exchange. No long-lived Hugging Face token or GitHub secret is needed. The workflow only receives a short-lived token scoped to the configured Space. The Space must remain Private; a private Space restricts both its source and running app to you and collaborators.

## Viewer controls

- Drag: orbit; pinch or wheel: zoom; two-finger drag: pan.
- Front, back, left, right, three-quarter and reset camera presets.
- Key/fill light intensity and key-light direction.
- Toggle hair, garments/armour, weapon, body hair, tattoo and piercings by mesh-name prefix.

The viewer loads the full character GLB and toggles mesh visibility. It is an inspection tool, not a full material editor or Godot substitute.

## Build outputs

The Blender source file and component GLBs are uploaded as a downloadable `wren-model-build` GitHub Actions artifact (14-day retention). The viewer and generated full model are uploaded to the private Hugging Face Space. Generated files are not committed back into the source repository.
