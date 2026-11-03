plugins {
    id("com.android.library") version "8.6.1"
}
android {
    namespace = "com.gaminghub.identity"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    val localGodot = providers.gradleProperty("godotAar").orNull
    if (localGodot != null) compileOnly(files(localGodot))
    else compileOnly("org.godotengine:godot:4.5.1.stable")
}
