package com.gaminghub.voice

import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceFocusPolicyTest {
    @Test fun notificationDucksAndGainRestoresWithoutTerminatingCall() {
        assertEquals(VoiceFocusPolicy.Action.DUCK, VoiceFocusPolicy.action(-3))
        assertEquals(VoiceFocusPolicy.Action.RESTORE, VoiceFocusPolicy.action(1))
    }
    @Test fun ExclusiveInterruptionAndPermanentLossStillStopMicrophone() {
        assertEquals(VoiceFocusPolicy.Action.STOP, VoiceFocusPolicy.action(-2))
        assertEquals(VoiceFocusPolicy.Action.STOP, VoiceFocusPolicy.action(-1))
    }
    @Test fun unrelatedChangesDoNotChangeSession() {
        assertEquals(VoiceFocusPolicy.Action.NONE, VoiceFocusPolicy.action(0))
    }
}
