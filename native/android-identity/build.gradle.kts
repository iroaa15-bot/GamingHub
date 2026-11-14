plugins {
    id("com.android.library") version "8.6.1"
}
android {
    namespace = "com.gaminghub.identity"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    defaultConfig { minSdk = 24; targetSdk = 36 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    implementation("androidx.credentials:credentials:1.5.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    implementation("com.facebook.android:facebook-login:19.0.0")
    val localGodot = providers.gradleProperty("godotAar").orNull
    if (localGodot != null) compileOnly(files(localGodot))
    else compileOnly("org.godotengine:godot:4.5.1.stable")
}
