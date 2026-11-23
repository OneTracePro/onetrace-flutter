group = "pro.onetrace.flutter"
version = "1.2.0"

/**
 * The native OneTrace SDK for Android. Until it is released, the code of its `stage-105` branch comes from mavenLocal
 * (`./gradlew publishToMavenLocal` in onetrace-android, see the README); after the release, JitPack serves a tag.
 */
val oneTraceAndroid = "1.2.0"

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

// The native SDK is published on JitPack: the app's projects resolve the plugin's dependencies too.
rootProject.allprojects {
    repositories {
        // Exclusive: the app's other repositories may come before mavenLocal in the list.
        exclusiveContent {
            forRepository { mavenLocal() }
            filter { includeGroupByRegex("com\\.github\\.OneTracePro.*") }
        }
        maven("https://jitpack.io") {
            content { includeGroupByRegex("com\\.github\\.OneTracePro.*") }
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
    implementation("com.github.OneTracePro.onetrace-android:onetrace:$oneTraceAndroid")
    implementation("com.github.OneTracePro.onetrace-android:onetrace-location:$oneTraceAndroid")
}
