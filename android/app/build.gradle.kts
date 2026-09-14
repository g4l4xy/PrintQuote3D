plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// This repository's authoritative shared files currently live in SharedSchemas.
// Expose that directory as assets/test resources without maintaining JSON copies.
val sharedSchemas = rootProject.layout.projectDirectory.dir("../SharedSchemas")

android {
    namespace = "local.printquote.android"
    compileSdk = 37
    defaultConfig {
        applicationId = "local.printquote.android"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    sourceSets {
        getByName("main").assets.directories.add(sharedSchemas.asFile.path)
        getByName("test").resources.directories.add(sharedSchemas.asFile.path)
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.03.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    testImplementation("junit:junit:4.13.2")
    // Android provides org.json at runtime; this supplies it to local JVM tests.
    testImplementation("org.json:json:20251224")
}
