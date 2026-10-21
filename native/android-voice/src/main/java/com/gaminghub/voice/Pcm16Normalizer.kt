package com.gaminghub.voice

import kotlin.math.abs
import kotlin.math.sqrt

/** Conservative fallback when Android AGC is unavailable. Never amplifies silence. */
class Pcm16Normalizer {
    private var gain = 1.0
    fun process(frame: ByteArray) {
        require(frame.size % 2 == 0)
        if (frame.isEmpty()) return
        var squares = 0.0
        var peak = 0
        for (i in frame.indices step 2) {
            val value = sample(frame, i)
            squares += value.toDouble() * value
            peak = maxOf(peak, abs(value))
        }
        val rms = sqrt(squares / (frame.size / 2))
        val target = if (rms < 180.0) 1.0 else minOf(2.5, 5000.0 / rms, 29000.0 / maxOf(1, peak))
        gain += (target - gain) * if (target < gain) 0.8 else 0.08
        val applied = minOf(gain, 29000.0 / maxOf(1, peak))
        for (i in frame.indices step 2) {
            val value = (sample(frame, i) * applied).toInt().coerceIn(-30000, 30000)
            frame[i] = value.toByte(); frame[i + 1] = (value shr 8).toByte()
        }
    }
    private fun sample(frame: ByteArray, i: Int): Int =
        ((frame[i].toInt() and 255) or (frame[i + 1].toInt() shl 8)).toShort().toInt()
}
