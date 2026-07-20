# iOS Widget Setup

## Requirements

- Xcode with the iOS 18 SDK or newer
- A physical iPhone running iOS 18 or newer for audio validation
- CocoaPods
- An Apple Developer team that owns the app and widget identifiers

## One-time signing setup

1. Register the App Group `group.com.vinscent.vinscent` in the Apple Developer portal.
2. Enable that App Group for both bundle identifiers:
   - `com.vinscent.vinscent`
   - `com.vinscent.vinscent.widgets`
3. Open `Runner.xcworkspace` and select the same development team for the `Runner` and `VinscentWidgets` targets.
4. Confirm the App Groups capability lists `group.com.vinscent.vinscent` on both targets.
5. Confirm the Runner target has Background Modes for audio and background processing.

## Build

```sh
cd apps/mobile
flutter pub get
cd ios
pod install
open Runner.xcworkspace
```

Build the `Runner` scheme. The `VinscentWidgets` extension is embedded through the Runner target dependency.

## Physical-device checks

1. Open the app once and grant microphone permission.
2. Add the Vinscent character and card widgets from the Home Screen widget gallery.
3. Confirm the character and latest partner card match the app.
4. Tap the character to play the cached recording and verify the bounce state ends with playback.
5. Tap the microphone button to start recording without opening the app.
6. Confirm the countdown ring starts at 12 o'clock, ends after 15 seconds, and can be stopped early.
7. Confirm the upload state clears and the new recording plays from both the app and widget.
8. Edit the card widget and verify all five tilt options.
9. Tap the card for each launch branch: card creation, question answer, and Home.
10. Disable Live Activities and microphone permission separately and verify the widget opens the app instead of attempting a background recording.

Widget audio and Live Activity behavior cannot be validated on Windows. Complete the signing and physical-device checks before release.
