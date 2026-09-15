plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// This repository's authoritative shared files currently live in SharedSchemas.
// Expose that directory as assets/test resources without maintaining JSON copies.
val sharedSchemas = rootProject.layout.projectDirectory.dir("../SharedSchemas")
val catalogAssets = tasks.register<Sync>("prepareCatalogAssets") {
    from(rootProject.file("../Sources/QuoteData/SeedData")) { include("open_filaments_v2.json") }
    from(rootProject.file("../ThirdParty")) { into("licenses") }
    from(rootProject.file("../LICENSE")) { into("licenses/PrintQuote") }
    from(rootProject.file("../ATTRIBUTION.md")) { into("licenses") }
    into(layout.buildDirectory.dir("generated/catalogAssets"))
}

android {
    namespace = "local.printquote.android"
    compileSdk = 37
    defaultConfig {
        applicationId = "local.printquote.android"
        minSdk = 26
        targetSdk = 37
        versionCode = 4
        versionName = "0.4.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    sourceSets {
        getByName("main").assets.directories.add(sharedSchemas.asFile.path)
        getByName("main").assets.directories.add(layout.buildDirectory.dir("generated/catalogAssets").get().asFile.path)
        getByName("test").resources.directories.add(sharedSchemas.asFile.path)
    }
}
tasks.named("preBuild").configure { dependsOn(catalogAssets) }

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.03.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    testImplementation("junit:junit:4.13.2")
    // Android provides org.json at runtime; this supplies it to local JVM tests.
    testImplementation("org.json:json:20251224")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.03.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test:runner:1.7.0")
    // 3.7 fixes InputManager reflection removed by newer Android versions.
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}
