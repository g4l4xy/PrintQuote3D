# Android Studio foundation

Open this `android/` directory in Android Studio and select the `app` run configuration. Allow Gradle sync, choose a device in Device Manager, then Run. Android Studio supplies the Gradle JDK and writes the ignored `local.properties` SDK location. Install SDK Platform 37 and Build Tools 36.0.0 through SDK Manager if needed.

## Toolchain

Pinned to Android Gradle Plugin 9.1.1, Gradle 9.3.1, built-in Kotlin 2.2.10, the matching Compose compiler, and Compose BOM 2026.03.00. These match the installed Android Studio 2026.1.4 and API 37 SDK. AGP 9 supplies Kotlin; do not also apply `org.jetbrains.kotlin.android`. Use Android Studio's bundled JDK (JDK 25 on the validation host; JDK 17+ supported by AGP).

Compatibility reference: https://developer.android.com/build/releases/agp-9-1-0-release-notes

The provisional application ID is `local.printquote.android`, following the Apple app's `local.printquote.desktop` prefix. Choose a permanent distribution ID before publishing.

## Shared data and behavior

The actual repository currently uses `SharedSchemas/`, not `shared/data/`. Android's main assets and JVM test resources point directly at `../SharedSchemas` through Gradle source sets. Gradle packages those inputs into the APK/test output; no JSON copies are checked into Android. Update the existing shared files to update both platforms. If the repository later moves those files, change the single `sharedSchemas` path in `app/build.gradle.kts`.

The shell reads `manufacturer_printers_v2.json` using Android's built-in JSON parser. `Printer` is only a projection of existing `vendor`, `model`, and `physicalToolheadCount` fields and supports 1–12 physical toolheads. It is not a new serialized schema. Other profile fields stay in the authoritative JSON. JVM tests read the exact same file; org.json is a test-only dependency because Android provides it on devices.

Compose → HomeViewModel → PrinterRepository is the complete foundation. The four home buttons open explicitly labeled placeholders. There is no database, networking, pricing implementation, or importer yet. Future pricing work must follow [the existing pricing specification](../docs/pricing-engine.md), the shared calculation fixtures, and Swift behavior. No empty pricing/importer packages were added.

## Command-line validation

With JAVA_HOME pointing to Android Studio's bundled JDK and the SDK configured:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. Build outputs, IDE metadata, and machine paths are ignored.

Validation on 2026-09-13: Gradle configuration/dependency resolution, `assembleDebug`, and all 3 `testDebugUnitTest` tests succeeded using the installed JDK 25/API 37 SDK. The managed validation session used writable workspace paths for `GRADLE_USER_HOME` and `ANDROID_USER_HOME`, plus `-Pkotlin.compiler.execution.strategy=in-process` to avoid sandbox restrictions on the compiler daemon. These are validation-environment overrides, not everyday Android Studio requirements. IDE UI sync was not separately exercised. No AVD/system image or connected device was available, so app launch remains unverified.
