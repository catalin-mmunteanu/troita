// Version set, all four of which move together:
//   Gradle wrapper 8.14.3 · AGP 8.11.1 · Kotlin 2.2.20 · JDK 17
// The floors come from the Flutter tool (>= AGP 8.6.0, >= Gradle 8.14.0 for
// Flutter 3.44), not from anything this project needs.
//
// Nothing may live under res/ that isn't a resource: every file there becomes
// an identifier and filenames are restricted to [a-z0-9_]. res/raw/ is absent
// for that reason — create it only when you add the bell sound.

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Must come after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ro.troita"

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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "ro.troita"
        // 24 rather than Flutter's default: the background path uses
        // stopForeground(int) and a handful of N-era APIs, and Android 7 is
        // under 1% of the Romanian install base.
        minSdk = 24
        // Deliberately behind compileSdk. Android 16 (API 36) tightens
        // notification and background rules; bump to 36 — Play will require
        // it — but retest the scheduled notifications when you do.
        targetSdk = 35
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
            // TODO: replace with a real upload key before publishing.
            signingConfig = signingConfigs.getByName("debug")
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
    implementation("com.google.android.gms:play-services-location:21.3.0")

    // Version-agnostic: the BOM keeps coroutines-android and
    // coroutines-play-services in lockstep with whatever Kotlin the Flutter
    // toolchain is using, instead of pinning 1.8.1 against a 2.x compiler.
    implementation(platform("org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.9.0"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android")
    // Task.await(), for the single fused-location call that centres the map.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services")
}
