package com.gaminghub.voice

import java.util.ArrayDeque

/** No microphone backlog can cross a pause, opt-out or stalled Godot frame. */
class CapturedFrames {
    private data class Frame(val bytes: ByteArray, val at: Long)
    private val frames = ArrayDeque<Frame>()
    @Synchronized fun offer(bytes: ByteArray, now: Long) {
        if (bytes.size != 640) return
        while (frames.size >= 5) frames.removeFirst()
        frames.addLast(Frame(bytes.copyOf(), now))
    }
    @Synchronized fun drain(now: Long): List<ByteArray> {
        while (frames.isNotEmpty() && now - frames.first.at > 100_000_000L) frames.removeFirst()
        // Keep at most 60 ms from a render stall instead of bursting stale audio.
        while (frames.size > 3) frames.removeFirst()
        val result = frames.map { it.bytes }
        frames.clear()
        return result
    }
    @Synchronized fun clear() = frames.clear()
}
