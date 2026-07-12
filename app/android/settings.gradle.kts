pluginManagement {
    val flutterSdkPath = System.getenv("FLUTTER_ROOT")
        ?: error("FLUTTER_ROOT env var not set — this must be set by flutter-action in CI or via local.properties on local dev machines")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")
