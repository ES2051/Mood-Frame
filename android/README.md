# Mood Frame Android

This is the native Android port of the SwiftUI `Mood Frame_0822` app.

Implemented:

- Splash, login, and sign-up flow with local mock auth.
- Main chat-style mood input screen.
- Mood record, diary, calendar, and image gallery screens.
- Side drawer navigation.
- BLE scan/connect flow for Galaxy/Android devices.

BLE target:

- Device name: `MoodFrame-EPD`
- Service UUID: `7a0247e0-4b3a-4bde-9e1f-1c9b6a4f9001`
- Image write characteristic: `7a0247e1-4b3a-4bde-9e1f-1c9b6a4f9002`
- Status characteristic: `7a0247e2-4b3a-4bde-9e1f-1c9b6a4f9003`

Open the `android` folder in Android Studio, sync Gradle, then run the `app` configuration on a Galaxy device.
