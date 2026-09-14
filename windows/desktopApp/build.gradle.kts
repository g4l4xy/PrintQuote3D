import org.jetbrains.compose.desktop.application.dsl.TargetFormat
plugins { alias(libs.plugins.kotlin); alias(libs.plugins.compose); alias(libs.plugins.composeCompiler) }
kotlin {
 jvmToolchain(21)
 sourceSets.main {
  kotlin.include("local/printquote/windows/**", "local/printquote/android/viewmodel/Draft.kt")
 }
}
dependencies { implementation(project(":sharedLogic")); implementation(compose.desktop.currentOs); implementation(compose.material3) }
tasks.processResources { from("../../assets/branding/generated/icon-256.png") { rename { "app-icon.png" } }; from("../../assets/branding/generated/mark-dark.png") { rename { "brand-mark.png" } } }
compose.desktop { application {
 mainClass = "local.printquote.windows.MainKt"
 nativeDistributions {
  targetFormats(TargetFormat.Msi, TargetFormat.Exe)
  packageName = "PrintQuote3D"
  packageVersion = "0.3.5"
  description = "Offline 3D printing estimates and workshop libraries"
  vendor = "PrintQuote3D"
  modules("java.sql", "java.naming", "jdk.unsupported")
  windows {
   iconFile.set(project.file("src/main/resources/PrintQuote3D.ico"))
   upgradeUuid = "33f2a4c9-1f44-4c76-b9b5-a7c5d6e90470"
   menuGroup = "PrintQuote3D"
   shortcut = true
   perUserInstall = true
   installationPath = "PrintQuote3D-App"
  }
 }
} }
