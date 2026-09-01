# Hollow Quest Android APK Wrapper Design

## Goal

Package the existing `hollow_quest_demo.html` game as an installable Android APK and build it automatically with GitHub Actions in the existing `sascov5-eng/AshenHollow` repository.

## Scope

- Preserve the existing HTML/Canvas/JavaScript game logic and touch controls.
- Add Android-specific files under a new `android/` directory so the existing iOS/source structure is not disrupted.
- Load the game locally from the APK; the game must not require network access to start or play.
- Use a minimal native Android shell with a single `WebView`.
- Force landscape orientation and immersive fullscreen mode.
- Enable JavaScript, DOM storage, local file asset loading, and hardware acceleration needed by the game.
- Disable unnecessary navigation outside the embedded game.
- Build a debug-signed APK suitable for direct installation on Android devices.
- Add a dedicated GitHub Actions workflow that builds and uploads the APK artifact.

## Architecture

The Android project will live in `android/` as a standalone Gradle project. The app module will contain a single `MainActivity` written in Kotlin. `MainActivity` hosts an Android `WebView` and loads `file:///android_asset/hollow_quest_demo.html` from `app/src/main/assets/`.

The user-provided HTML game is copied into the Android assets directory without changing gameplay rules. Android-specific behavior such as fullscreen, landscape orientation, back-button handling, and WebView configuration is implemented in native code rather than mixed into the game file.

GitHub Actions will use Ubuntu, JDK 17, Android SDK tooling available on the GitHub runner, and Gradle to run `assembleDebug`. The resulting `app-debug.apk` will be copied/renamed to `HollowQuest.apk` and uploaded as a workflow artifact.

## Planned Files

- `android/settings.gradle.kts` — Gradle project definition.
- `android/build.gradle.kts` — root Android Gradle configuration.
- `android/gradle.properties` — AndroidX/Gradle settings.
- `android/app/build.gradle.kts` — application module configuration.
- `android/app/src/main/AndroidManifest.xml` — app metadata, landscape orientation, hardware acceleration.
- `android/app/src/main/java/com/ashenhollow/hollowquest/MainActivity.kt` — fullscreen WebView host.
- `android/app/src/main/assets/hollow_quest_demo.html` — embedded game.
- `android/app/src/main/res/values/strings.xml` — application name.
- `android/app/src/main/res/values/themes.xml` — fullscreen/no-action-bar theme.
- `.github/workflows/build-apk.yml` — reproducible APK build and artifact upload.

## Android Behavior

- Application name: `Hollow Quest`.
- Package/application ID: `com.ashenhollow.hollowquest`.
- Orientation: landscape only.
- Display: fullscreen immersive mode with system bars hidden while playing.
- WebView background: dark to avoid white flashes during launch.
- JavaScript: enabled.
- DOM storage: enabled.
- Media playback does not require user gesture if later used by the game.
- Overscroll and zoom UI: disabled.
- External HTTP/HTTPS navigation: blocked from replacing the game view.
- Android Back: does not exit into WebView history; it closes the activity only when appropriate.

## Build Configuration

- Kotlin/JVM target: Java 17.
- Android compile SDK: 35.
- Android target SDK: 35.
- Minimum Android SDK: 23 (Android 6.0+).
- Build variant: `debug`.
- Output artifact name presented by CI: `HollowQuest.apk`.
- No Play Store signing or release keystore is required for this first build.

## GitHub Actions

The `build-apk.yml` workflow will:

1. Check out the repository.
2. Set up JDK 17.
3. Set up Gradle.
4. Build `android/app` with `assembleDebug`.
5. Verify that the APK exists.
6. Rename/copy it to `HollowQuest.apk`.
7. Upload it as a GitHub Actions artifact.

The workflow will run on manual dispatch and on pushes that change `android/**`, `.github/workflows/build-apk.yml`, or the embedded game asset.

## Validation

A successful implementation must satisfy all of the following:

- Gradle configuration resolves successfully on GitHub Actions.
- `assembleDebug` completes without errors.
- `HollowQuest.apk` is present in the workflow artifacts.
- The APK installs on Android 6.0 or newer.
- Launching the APK opens the game directly, without browser chrome.
- The game is playable offline.
- Touch left/right/jump/attack/dash controls continue to work.
- The app stays in landscape fullscreen during gameplay.
- Existing iOS workflows and source files remain unchanged.

## Non-Goals

- Google Play publishing.
- Release signing with a private keystore.
- Ads, analytics, in-app purchases, accounts, cloud saves, or networking.
- Rewriting the HTML game in a native engine.
- Redesigning the game UI or gameplay in this task.
