import java.security.MessageDigest

plugins {
    id("com.android.library") version "8.10.1"
    id("org.jetbrains.kotlin.android") version "2.1.20"
}
android {
    namespace = "com.gaminghub.voice"
    compileSdk = 36
    defaultConfig { minSdk = 24; consumerProguardFiles("consumer-rules.pro") }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildTypes { release { isMinifyEnabled = false } }
    testOptions { unitTests.isReturnDefaultValues = false }
}
dependencies {
    compileOnly("org.godotengine:godot:4.5.1.stable")
    implementation("io.github.webrtc-sdk:android:144.7559.15")
    testImplementation("junit:junit:4.13.2")
}
tasks.register<Copy>("installPlugin") {
    dependsOn("assembleDebug", "assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar")) { include("*.aar") }
    into(rootProject.file("../../addons/gaminghub_voice/bin"))
}

// Bind distributed binaries to the reviewed native source; fail preflight on stale AARs.
val voiceBuildInfo = tasks.register("generateVoiceBuildInfo") {
    val sourceFiles = fileTree("src/main") { include("**/*.kt", "**/AndroidManifest.xml") }.files +
        listOf(file("build.gradle.kts"), file("settings.gradle.kts"), file("gradle.properties"), file("consumer-rules.pro"))
    inputs.files(sourceFiles)
    val output = layout.buildDirectory.file("generated/voice-assets/gaminghub_voice_build.json")
    outputs.file(output)
    doLast {
        val digest = MessageDigest.getInstance("SHA-256")
        for (source in sourceFiles.sortedBy { it.relativeTo(projectDir).invariantSeparatorsPath }) {
            digest.update((source.relativeTo(projectDir).invariantSeparatorsPath + "\u0000").toByteArray(Charsets.UTF_8))
            digest.update(source.readText().replace("\r\n", "\n").toByteArray(Charsets.UTF_8))
            digest.update(0.toByte())
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it) }
        output.get().asFile.apply {
            parentFile.mkdirs()
            writeText("{\"protocol\":2,\"source_sha256\":\"$hash\"}\n")
        }
    }
}
android.sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/voice-assets"))
tasks.named("preBuild") { dependsOn(voiceBuildInfo) }
