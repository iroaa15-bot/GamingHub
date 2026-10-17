plugins {
    id("com.android.library") version "8.7.3"
    id("org.jetbrains.kotlin.android") version "2.0.21"
}

android {
    namespace = "com.iroaa15.gaminghub.voice"
    compileSdk = 35
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    // Not yet verified or compiled: pin a compatible Godot Android API
    // and a maintained WebRTC Android binary before enabling compilation.
    compileOnly("org.godotengine:godot:4.5.1.stable")
    implementation("io.github.webrtc-sdk:android:150.7871.01")
    implementation("androidx.core:core-ktx:1.13.1")
}

 // Stage the exact resolved runtime dependencies for later isolated APK
 // integration. This does NOT modify the game's current export templates.
tasks.register<Copy>("stageVoiceRuntime") {
    dependsOn("assembleDebug")
    from(configurations.named("debugRuntimeClasspath"))
    from(layout.buildDirectory.file("outputs/aar/voice-plugin-debug.aar"))
    into(layout.buildDirectory.dir("voice-runtime-staging"))
    duplicatesStrategy = DuplicatesStrategy.FAIL
}
