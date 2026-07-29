pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
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
    // AGP 8.9.1 是 androidx.core 1.17 / androidx.browser 1.9(由 url_launcher 與
    // permission_handler 帶進來)的最低要求;低於它 `assembleDebug` 會在
    // checkDebugAarMetadata 直接失敗。#32 的 integration job 才抓到這件事——
    // 先前沒有任何 CI job 會實際建置 Android app。
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

include(":app")
