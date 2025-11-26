# Voice Camera App

Voice-activated countdown camera proof-of-concept for iOS. The app will idle in a listening state, react to a configurable keyword (default: "camera me"), play a countdown animation with audible cues, then capture and store a photo using the selected camera.

## Current Status
- ✅ Repo initialized with base directory structure, documentation stubs, and a runnable SwiftUI Xcode project (`VoiceCameraApp.xcodeproj`)
- 🔜 Implement microphone + speech trigger pipeline
- 🔜 Wire up camera preview, capture pipeline, and countdown UX
- 🔜 Add assets (beeps + shutter), permissions copy, and run-book instructions

## Planned Features
- Continuous microphone monitoring that works with on-device and accessory mics
- Customizable trigger phrase with live status indicator
- 5-second animated countdown with per-second beep followed by shutter sound
- Camera preview with front/back toggle and auto-save to Photos
- Documentation + video walkthrough covering setup, architecture, and trade-offs

## Repository Layout
```
Sources/
  App/            # SwiftUI entry point + root scene wiring
  Audio/          # Speech recognition + trigger detection services
  Camera/         # Camera session management + capture logic
  Countdown/      # Animation + audio feedback components
  Extensions/     # Cross-cutting utilities / shared helpers
Resources/
  Assets.xcassets # App icon + accent color (ready for additional assets)
  Sounds/         # Audio cues for countdown + shutter
Config/            # Environment, entitlement, and credential templates
Docs/              # Assignment brief, architecture notes, and run book
```

## Getting Started (current scaffolding)
1. Open `VoiceCameraApp.xcodeproj` in Xcode 15+.
2. Update the bundle identifier + signing team under *Signing & Capabilities* once developer credentials arrive.
3. Select a physical device target (mic/camera permissions only work on device) and build/run.
4. You should see the placeholder SwiftUI screen; speech, countdown, and capture flows are upcoming.

## Next Steps
- Implement the speech trigger service using `AVAudioEngine` + `SFSpeechRecognizer`.
- Build countdown animation + audio feedback and integrate with camera capture.
- Add photo library save flow + permission prompts.
- Record walkthrough video and finalize README instructions.
