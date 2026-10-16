// Version set, all four of which move together:
//   Gradle wrapper 8.14.3 · AGP 8.11.1 · Kotlin 2.2.20 · JDK 21
// The floors come from the Flutter tool (>= AGP 8.6.0, >= Gradle 8.14.0 for
// Flutter 3.44), not from anything this project needs.
//
// Nothing may live under res/ that isn't a resource: every file there becomes
// an identifier and filenames are restricted to [a-z0-9_]. res/raw/ is absent
// for that reason — create it only when you add the bell sound.

import java.io.FileInputStream
import java.util.Properties

// Release signing, read from android/key.properties — the standard Flutter
// layout. That file and the keystore it points to are gitignored and must
// never be committed: the upload key is the app's identity on Play.
//
//   storePassword=…
//   keyPassword=…
//   keyAlias=upload
//   storeFile=../upload-keystore.jks
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Must come after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ro.troita"

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    // Literals rather than flutter.compileSdkVersion: that accessor only exists
    // on the Kotlin DSL extension in recent Flutter versions, and an unresolved
    // reference here fails the configuration phase with a message that points
    // at the wrong thing.
    //
    // 36 because current plugin releases (permission_handler, sqflite) are built
    // against it; Gradle downloads the platform automatically if it is missing.
    compileSdk = 36

    compileOptions {
        // flutter_local_notifications uses java.time, which only exists from
        // API 26. Desugaring backports it so scheduling works on Android 7–8 —
        // required by the plugin from v10 onward whether or not you schedule
        // anything, so this is not optional.
        isCoreLibraryDesugaringEnabled = true
        // 21, not 17, because maplibre_gl compiles its own Android module at
        // Java 21. A library's class files cannot be consumed by a build whose
        // JDK is older than the bytecode it emits, so this is forced from
        // outside — the whole Gradle daemon must run on JDK 21.
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    // The highest NDK any plugin asks for. They are backward compatible, so
    // the highest wins and every other plugin builds against it.
    //
    //   maplibre_gl                 28.2.13676358   <- this one
    //   flutter_local_notifications 27.0.12077973
    //   permission_handler_android  27.0.12077973
    //   shared_preferences_android  27.0.12077973
    //   sqflite_android             27.0.12077973
    //
    // Re-check when maplibre_gl is upgraded. Flutter prints the whole table at
    // build time and names the version to use, so this is never a guess — the
    // 28.1 that was here first came from reading the plugin's build.gradle on
    // its main branch rather than the release actually installed.
    ndkVersion = "28.2.13676358"

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "ro.troita"
        // 24 rather than Flutter's default: the background path uses
        // stopForeground(int) and a handful of N-era APIs, and Android 7 is
        // under 1% of the Romanian install base.
        minSdk = 24
        // 36 because Google Play requires it: since 31 August 2026 new apps and
        // updates must target Android 16. What changes for this app when it
        // does: predictive back is on by default (Flutter handles it, and the
        // manifest opts in explicitly), and edge-to-edge can no longer be opted
        // out of — already true at 35. Scheduled notifications use inexact
        // alarms, which Android 16 leaves alone. Retest a notification and the
        // back gesture on a device after building.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Desugaring pulls in enough method references to risk the 64K DEX
        // limit on older builds. The plugin's own README asks for this.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Off for now. Turn it back on with proguard-rules.pro once the app
            // is stable, then verify a scheduled notification still fires — R8
            // is exactly the kind of thing that quietly strips a receiver.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // The real key when key.properties exists; otherwise the debug
            // key, so `flutter run --release` keeps working on a machine
            // without it. An APK signed with the debug key cannot be uploaded
            // to Play, which is the safety net: it fails loudly at upload
            // rather than shipping something nobody can update.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    // The seed database is already compact; leaving it uncompressed lets us
    // stream it straight out of the APK rather than inflating it in RAM once
    // the dataset grows past one county.
    androidResources {
        noCompress += "db"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Version taken from the plugin's own android/build.gradle, not guessed —
    // flutter_local_notifications 22.3.0 builds against desugar_jdk_libs 2.1.4.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.core:core-ktx:1.13.1")

    // Version-agnostic: the BOM keeps coroutines in lockstep with whatever
    // Kotlin the Flutter toolchain is using, instead of pinning 1.8.1 against a
    // 2.x compiler. The bridge still runs its channel calls on Dispatchers.IO.
    //
    // play-services-location and coroutines-play-services were here for a
    // fused-location call that only an unreachable screen used. Gone with it.
    implementation(platform("org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.9.0"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android")
}
