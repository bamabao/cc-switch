pluginManagement {
    val flutterSdkPath = run {
        // CI: FLUTTER_ROOT env var from flutter-action; local: local.properties
        val envSdk = System.getenv("FLUTTER_ROOT")
        if (envSdk != null) return@run envSdk
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val sdk = properties.getProperty("flutter.sdk")
        require(sdk != null) { "flutter.sdk not set in local.properties, and FLUTTER_ROOT env is not set" }
        sdk
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

include(":app")
