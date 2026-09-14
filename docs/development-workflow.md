# One workflow for Apple and Android

Both apps are in this repository. One Git commit, branch, push or pull includes changes for both. App source updates do not synchronize customer/quote data and do not automatically update installed apps; rebuild/run after pulling.

## Quick controls

On a Mac, double-click **PrintQuote Workflow.command** in the repository. It offers Status, Pull, Check both, Push all edits, and Start feature. Python 3, Git, Xcode and Android Studio/SDK are required. The launcher shows edits before asking for the push commit message; blank cancels.

From Terminal at the repository root:

```sh
./pq status
./pq pull
./pq check
./pq push -m "Add the feature to Apple and Android" -- Sources android SharedSchemas docs
```

For a deliberate commit of all non-ignored edits:

```sh
./pq push --all -m "Describe the update"
```

Push commits the chosen paths and publishes the current branch to origin. Existing staged files cause it to stop so another staged selection is not silently included. A rejected push retains the local commit. Pull requires a clean checkout and an upstream branch and only fast-forwards. It does not stash, overwrite or resolve conflicts for you. After committing outstanding changes you can resolve a divergence with ordinary Git, review it, then push.

Each clone has its own working copy. Push from the copy where you made changes, then run `./pq pull` in another clean clone. A feature branch stays a feature branch: pushing it does not merge it into main. Open a pull request to merge the completed feature.

## Add one feature to both apps

```sh
./pq pull
./pq feature quote-pdf-export "Export a customer quote as PDF"
```

This creates `feature/quote-pdf-export` and `docs/features/quote-pdf-export.md`. Fill in the shared outcome and acceptance examples, then implement the Swift and Kotlin changes on that branch. The template is a plan, not a generated implementation.

A useful request to a coding assistant is:

> Implement the feature described in docs/features/quote-pdf-export.md for both Apple and Android. Follow AGENTS.md, reuse SharedSchemas, add matching behavior tests, run ./pq check and record the results. Keep unverified interaction coverage explicit.

Use `./pq check` when ready and publish the feature's selected files. GitHub's feature issue and pull request templates keep both platforms visible during review. Both apps share data contracts and expected results; SwiftUI and Compose interfaces still require native implementations.

## Checks and builds

`./pq check` runs Apple and Android checks concurrently and returns failure if either fails. Full logs are in `.workflow/apple.log` and `.workflow/android.log` (ignored by Git).

- Apple: `swift test`, Xcode macOS build, and Xcode iOS Simulator build. The iOS target also targets iPad.
- Android: debug APK build, JVM tests and Android lint.
- Optional targeted checks: `./pq check --platform apple` or `./pq check --platform android`.
- Android interaction tests with a running emulator: `./android/gradlew -p android :app:connectedDebugAndroidTest`.
- Apple interactions: run the app on Mac/iPhone/iPad destinations in Xcode and record the tested workflows.

Android Studio's bundled JDK and the standard macOS SDK directory are detected when JAVA_HOME/ANDROID_HOME are unset. Existing environment values are honored. Install the pinned Android SDK/build tools listed in android/README.md. Select the full Xcode developer directory for Apple builds.

After pulling, open `PrintQuote3D.xcodeproj` for Apple and `android/` for Android Studio, then Run. The Android debug APK is `android/app/build/outputs/apk/debug/app-debug.apk`. To package the Mac development app, run `./Scripts/build-app.sh`. These are development builds; the workflow does not publish to app stores or perform signed releases.
