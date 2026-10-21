"""Static crash-regression gates for Android voice code. No Android runtime claim."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "scripts/multiplayer.gd"
NATIVE = ROOT / "native/android-voice/src/main/java/com/gaminghub/voice"


class VoiceCrashRegression(unittest.TestCase):
    def test_diagnostics_never_initializes_native_audio(self):
        text = GAME.read_text(encoding="utf-8")
        method = text.split("func _voice_diagnostics_text() -> String:", 1)[1].split(
            "\nfunc _show_voice_diagnostics() -> void:", 1
        )[0]
        statements = "\n".join(line for line in method.splitlines()
                               if not line.strip().startswith("#"))
        for forbidden in (
            "_setup_native_voice(", "Engine.get_singleton(", ".is_available(",
            "request_permission(", "startWebRtcVoice(", "startVoice(",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, statements)

    def test_only_unregister_registered_audio_callbacks(self):
        for name in ("AndroidVoiceEngine.kt", "WebRtcVoiceEngine.kt"):
            with self.subTest(engine=name):
                code = (NATIVE / name).read_text(encoding="utf-8")
                self.assertIn("private var deviceCallbackRegistered = false", code)
                self.assertIn("deviceCallbackRegistered = true", code)
                self.assertIn("if (deviceCallbackRegistered) {", code)
                self.assertIn("manager.unregisterAudioDeviceCallback(devices)", code)
                self.assertLess(code.index("if (deviceCallbackRegistered) {"),
                                code.index("manager.unregisterAudioDeviceCallback(devices)"))

    def test_voice_is_opt_in_and_isolated_from_lobby_navigation(self):
        code = GAME.read_text(encoding="utf-8")
        self.assertIn("voice_button.pressed.connect(func(): set_voice_opt_in(not voice_requested))", code)
        self.assertIn("func _setup_native_voice()", code)
        self.assertIn("func _voice_room_ready()", code)


if __name__ == "__main__":
    unittest.main()
