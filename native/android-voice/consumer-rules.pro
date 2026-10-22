-keep class com.gaminghub.voice.GamingHubVoicePlugin { *; }
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot <methods>;
}

-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
