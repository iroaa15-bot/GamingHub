package com.gaminghub.voice

/** Android focus constants are kept here so interruption policy is JVM-testable. */
internal object VoiceFocusPolicy {
    enum class Action { RESTORE, DUCK, STOP, NONE }
    fun action(change: Int): Action = when (change) {
        1 -> Action.RESTORE // AUDIOFOCUS_GAIN
        -3 -> Action.DUCK // AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK: notification
        -1, -2 -> Action.STOP // Permanent loss or exclusive transient interruption.
        else -> Action.NONE
    }
}
