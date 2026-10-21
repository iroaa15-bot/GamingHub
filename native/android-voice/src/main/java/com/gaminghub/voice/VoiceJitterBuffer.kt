package com.gaminghub.voice

import java.util.ArrayDeque

/** Ordered WS transport: bounded rebuffering, deduplication, no stale speech replay. */
class VoiceJitterBuffer {
    private data class Frame(val bytes: ByteArray, val arrival: Long)
    private val frames = ArrayDeque<Frame>()
    private var lastSequence = -1
    private var primed = false
    @Synchronized fun offer(bytes: ByteArray, sequence: Int, now: Long): Boolean {
        if (bytes.size != 640 || sequence < 0 || sequence <= lastSequence) return false
        lastSequence = sequence
        while (frames.size >= 6) frames.removeFirst()
        frames.addLast(Frame(bytes.copyOf(), now))
        return true
    }
    @Synchronized fun poll(now: Long): ByteArray? {
        while (frames.isNotEmpty() && now - frames.first.arrival > 160_000_000L) frames.removeFirst()
        if (frames.isEmpty()) { primed = false; return null }
        if (!primed) {
            if (frames.size < 3 && now - frames.first.arrival < 60_000_000L) return null
            primed = true
        }
        return frames.removeFirst().bytes
    }
    @Synchronized fun clear() { frames.clear(); lastSequence = -1; primed = false }
}
