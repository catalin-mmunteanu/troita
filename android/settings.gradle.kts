pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Floors imposed by the Flutter tool, not by this project:
//   Flutter 3.44 requires AGP >= 8.6.0 and warns below Gradle 8.14.0.
// AGP 8.11 requires Gradle 8.13+, so the wrapper is on 8.14.3. AGP 8.11 rather
// than 8.9 because compileSdk 36 is only properly supported from 8.11 — on
// older AGP it builds but warns that the SDK is untested.
// If you upgrade Flutter and it complains again, raise all three together —
// they are a matched set, and bumping one alone produces errors that point at
// the wrong file.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
