group = "pro.onetrace.flutter"
version = "1.2.0"

/**
 * The native OneTrace SDK for Android from JitPack. Until it is released, a commit of its `stage-105` branch (JitPack
 * builds any commit); after the release, a tag. Gradle properties of the app (`android/gradle.properties`):
 * - `onetrace.geofences=true` adds `onetrace-location` (geofences): Google Play services Location and the location
 *   permissions in the app manifest. Without it the app gets neither, and `enableGeofences` returns `unavailable`.
 * - `onetrace.mavenLocal=true` takes the native SDK from the local Maven repository instead (a working copy of
 *   onetrace-android published with `publishReleasePublicationToMavenLocal`, version `onetrace.androidVersion`, 1.2.0
 *   by default).
 */
val oneTraceMavenLocal = providers.gradleProperty("onetrace.mavenLocal").orNull == "true"
val oneTraceAndroid = providers.gradleProperty("onetrace.androidVersion").orNull ?: if (oneTraceMavenLocal) "1.2.0" else "5571a7abd4"
val oneTraceGeofences = providers.gradleProperty("onetrace.geofences").orNull == "true"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The native SDK is published on JitPack: the app's projects resolve the plugin's dependencies too. The local Maven
// repository serves it only when the app asks for it, and then exclusively (the app's other repositories may come first).
rootProject.allprojects {
    repositories {
        if (oneTraceMavenLocal) {
            exclusiveContent {
                forRepository { mavenLocal() }
                filter { includeGroupByRegex("com\\.github\\.OneTracePro.*") }
            }
        } else {
            maven("https://jitpack.io") {
                content { includeGroupByRegex("com\\.github\\.OneTracePro.*") }
            }
        }
    }

    // The modules of the native SDK refer to each other by their own version: all of them in the version above.
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.github.OneTracePro.onetrace-android") {
                useVersion(oneTraceAndroid)
            }
        }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "pro.onetrace.flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // `api`: the app starts the native SDK in its Application for geofences in the background (README).
    api("com.github.OneTracePro.onetrace-android:onetrace:$oneTraceAndroid")
    // Geofences are compiled against, but reach the app only with `onetrace.geofences=true`.
    compileOnly("com.github.OneTracePro.onetrace-android:onetrace-location:$oneTraceAndroid")
    if (oneTraceGeofences) {
        implementation("com.github.OneTracePro.onetrace-android:onetrace-location:$oneTraceAndroid")
    }
}
