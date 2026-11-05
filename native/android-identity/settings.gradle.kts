pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
    resolutionStrategy { eachPlugin {
        if (requested.id.id == "com.android.library") useModule("com.android.tools.build:gradle:${requested.version}")
    } }
}
dependencyResolutionManagement { repositories { google(); mavenCentral() } }
rootProject.name = "gaminghub-identity"
