# Voice Camera App

Voice-activated countdown camera proof-of-concept for iOS. The app continuously listens for a configurable phrase (default: **“camera me”**), starts a 5-second animated countdown with beeps, then captures and saves a photo with a shutter sound using the active camera (front by default). Works with device and accessory mics (e.g., AirPods) and dynamically shows only available lenses (0.5x/1x/2x/3x/5x).

## Developer Account Note
The app needs camera, microphone, speech, and photo-library permissions on device. Sign the target with an Apple Developer account to run on hardware.

## Requirements
- Xcode 15 or newer (Swift 5.9+)
- iOS 17+ device (mic/camera/photo access require hardware)
- Apple Developer signing set on the `VoiceCameraApp` target

## Quick Start
1. Open `VoiceCameraApp.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, set your Team and a unique Bundle Identifier.
3. Select a physical device target (not Simulator) and run.
4. Grant microphone, speech, and Photos access when prompted.

## How to Use
- **Trigger phrase:** Default “camera me”. Update it in Settings → Voice Trigger; stored in `UserDefaults` and applied immediately.
- **Listening indicator:** Mic button shows On/Off and uses accent color when active.
- **Countdown:** 5-second default with per-second beeps and shutter at capture; timer durations 3s/5s/10s are configurable in the timer control.
- **Camera & lenses:** Toggle front/back; lens buttons show only supported zoom factors (0.5x/1x/2x/3x/5x).
- **Flash & aspect ratio:** Flash cycles Auto/On/Off; aspect ratio cycles common presets from the top bar.
- **Grid lines:** Toggle on/off to help composition.
- **Themes:** Auto/Light/Dark; Auto follows the system setting live. Changes apply immediately without leaving Settings.
- **Save:** Captured photo is written to Photos (add-only permission).
- **Speech test:** Use the mic button to start/stop listening and verify recognition status; change the trigger phrase to validate speech recognition.

## Validation Checklist (assignment-aligned)
- Launch prompts for microphone and speech permissions; Photos add-only requested on first save.
- Saying the trigger phrase starts the 5s countdown (with animation + beep each second).
- Shutter sound at the end; photo saved to camera roll.
- Works with device mic and AirPods/headphones.
- Trigger phrase is editable and persists.
- Camera toggle and dynamic zoom options reflect available lenses.
- Flash, aspect ratio, grid, and timer controls respond as expected; timer honors 3s/5s/10s values.
- Theme picker switches among Auto/Light/Dark; Auto mirrors the current system theme.

## Run/Build Options
- **Standard build:** Run from Xcode on device after setting signing.
- **Assets:** Beep and shutter use system sounds (`Tock.caf`, `photoShutter.caf`) via `SoundEffectsPlayer`; no extra assets required.
- **Audio routing:** Output stays on the main speaker unless an external route (Bluetooth/headphones) is active, in which case system routing is honored.

## Project Layout
```
Sources/
  App/            Entry point, scene setup, appearance handling
  Audio/          Speech trigger service, permissions, sound effects
  Camera/         Capture session, dynamic lenses, capture pipeline
  Components/     UI elements (controls bar, buttons, cards)
  Views/          SwiftUI screens (Camera, Settings, Root)
  Models/         Simple models and permission utilities
Resources/
  Assets.xcassets App icon + colors
  Sounds/         System-backed audio hooks (see SoundEffectsPlayer)
Docs/             Assignment and workflow notes
```

## Permissions Behavior
- **Microphone & Speech:** Requested on first launch; listener won’t start without both.
- **Photos:** Requested with add-only scope on first save; failures surface inline in the camera UI.

## Notes and Trade-offs
- Speech trigger uses `SFSpeechRecognizer` with `AVAudioEngine`; continuous listening, retried on transient failures.
- Countdown + sounds use `AVAudioPlayer` for reliability while recording audio; haptics back up the timer beeps.
- Dynamic zoom options derive from `AVCaptureDevice` virtual device switch-over factors; lenses are shown only if available.

## Validation Script (manual)
1. Install and launch on device; accept mic/speech prompts.
2. Say “camera me” → observe 5s countdown with beeps.
3. At 0 → shutter sound plays and photo saves to Photos.
4. Toggle cameras; verify only supported zoom factors appear.
5. Edit trigger phrase; confirm new phrase triggers capture.
6. Repeat with AirPods/headphones to verify accessory mic + audio routing.
