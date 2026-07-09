pluginManagement {
    val flutterSdkPath = run {
        // 优先从 local.properties 读取 Flutter SDK 路径
        val localProps = file("local.properties")
        if (localProps.exists()) {
            val properties = java.util.Properties()
            localProps.inputStream().use { properties.load(it) }
            val sdk = properties.getProperty("flutter.sdk")
            if (sdk != null) return@run sdk
        }
        // CI 环境降级方案：从 FLUTTER_ROOT 环境变量读取
        val envSdk = System.getenv("FLUTTER_ROOT")
        if (envSdk != null) return@run envSdk
        error("flutter.sdk not found: neither local.properties nor FLUTTER_ROOT is set")
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
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")
