plugins { alias(libs.plugins.kotlin); alias(libs.plugins.serialization); `java-library` }
kotlin {
 jvmToolchain(21)
 sourceSets.main {
  kotlin.srcDir("../../android/app/src/main/java")
  kotlin.include("local/printquote/windows/**", "local/printquote/android/model/Documents.kt", "local/printquote/android/pricing/PricingEngine.kt", "local/printquote/android/data/WorkspaceRepository.kt", "local/printquote/android/data/ModelImport.kt")
 }
}
dependencies { api(libs.json); implementation(libs.serialization); implementation(libs.sqlite); implementation(libs.gson); testImplementation(libs.junit) }
sourceSets.test { java.srcDir("../../android/app/src/test/java"); java.include("**/ParityTests.kt", "**/ModelImportTests.kt") }
sourceSets.main { resources.srcDir("../../SharedSchemas") }
tasks.processResources {
 from("../../Sources/QuoteData/SeedData") { include("open_filaments_v2.json") }
 from("../../ThirdParty") { into("licenses") }
 from("../../ATTRIBUTION.md") { into("licenses") }
}
