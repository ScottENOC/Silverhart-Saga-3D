# iOS build target

Silverhart Saga 3D targets iPhone 17 as a supported mobile device.

## Current CI foundation

- Godot 4.7.2 stable, standard GDScript (not .NET).
- iOS export preset is named `iOS`.
- GitHub Actions uses a macOS runner with Xcode and Godot export templates.
- CI imports the project, exports an Xcode project, and attempts an unsigned device-SDK compile.
- CI deliberately does not create an installable IPA or store Apple signing credentials.

The current bundle identifier is a project placeholder: `com.scottenoc.silverhartsaga`. The App Store Team ID in the preset is also a syntactically valid placeholder and must be replaced with the user's actual Apple Team ID before signing/distribution. Do not put certificates, private keys, provisioning profiles, or passwords in the repository.

## Installation path

For early personal testing, a signed IPA can later be installed with the user's existing AltStore setup. A free Apple Personal Team is subject to short-lived provisioning; a paid Apple Developer Program membership enables a more durable TestFlight/App Store workflow. The unsigned CI artifact is not directly installable.

## Input design target

The mobile input implementation is a separate gameplay task and must use the existing game command layer:

- Touch: tap-to-select/tap-to-move on hexes, contextual interactions, camera drag/pinch, and optional virtual movement controls where free movement is used.
- Gamepad: left stick movement, right stick camera, face buttons for confirm/interact/cancel, and shoulder buttons/triggers for context actions.
- Hybrid: touch selection and menus remain available while a gamepad is connected.
- UI: landscape-first layout, safe-area-aware HUD, scalable controls, and no controls obscuring the game view.

Do not duplicate movement, interaction, or combat logic across input methods. Map each device to shared semantic actions.

## Rendering

The project already declares Godot's Mobile renderer for mobile exports. Keep the desktop Forward+ and web Compatibility renderer settings separate. Validate visual effects, materials, shadows, and performance on real iPhone hardware; the iOS Simulator is not a substitute for device rendering/performance validation.


### iOS texture import requirement

The iOS export platform requires ETC2/ASTC texture variants to be imported. The project enables
`rendering/textures/vram_compression/import_etc2_astc=true` so those variants are generated
on the macOS CI runner as well as on developer machines. This is separate from Apple code signing
and does not require a paid Apple Developer membership.
