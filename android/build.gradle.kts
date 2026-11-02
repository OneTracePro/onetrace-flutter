group = "pro.onetrace.flutter"
version = "1.0.0"

/** The native OneTrace SDK for Android (JitPack: a release tag or a commit). */
val oneTraceAndroid = "1.1.0"

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
}
