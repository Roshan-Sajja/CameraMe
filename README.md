# Voice Camera App

Voice-activated countdown camera proof-of-concept for iOS. The app will idle in a listening state, react to a configurable keyword (default: "camera me"), play a countdown animation with audible cues, then capture and store a photo using the selected camera.

## Current Status
- ✅ Repo initialized with base directory structure and documentation stubs
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
  Assets/         # Media assets, e.g., shutter/beep sounds, icons
  Sounds/
Config/            # Environment, entitlement, and credential templates
Docs/              # Assignment brief, architecture notes, and run book
```

## Getting Started (once implementation lands)
1. Open the upcoming Xcode project/workspace once committed.
2. Update the bundle identifier + signing team for your developer account.
3. Run on a real device (required for mic/camera access) to grant permissions.
4. Speak "camera me" (or a custom trigger) and verify countdown + capture.

## Next Steps
- Scaffold the actual Xcode project with SwiftUI + AVFoundation targets.
- Implement the speech trigger service using `AVAudioEngine` + `SFSpeechRecognizer`.
- Build countdown animation + audio feedback and integrate with camera capture.
- Add photo library save flow + permission prompts.
- Record walkthrough video and finalize README instructions.
