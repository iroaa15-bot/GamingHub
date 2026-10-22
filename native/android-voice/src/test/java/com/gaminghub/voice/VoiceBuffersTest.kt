package com.gaminghub.voice

import org.junit.Assert.*
import org.junit.Test

class VoiceBuffersTest {
    private fun frame(value: Int) = ByteArray(640).also { bytes ->
        for (i in bytes.indices step 2) { bytes[i] = value.toByte(); bytes[i+1] = (value shr 8).toByte() }
    }
    private fun sample(bytes: ByteArray) = ((bytes[0].toInt() and 255) or (bytes[1].toInt() shl 8)).toShort().toInt()
    @Test fun jitterPrimesThreeFrames() {
        val q = VoiceJitterBuffer()
        q.offer(frame(1), 1, 0); assertNull(q.poll(0))
        q.offer(frame(2), 2, 20_000_000); assertNull(q.poll(20_000_000))
        q.offer(frame(3), 3, 40_000_000); assertEquals(1, sample(q.poll(40_000_000)!!))
        assertEquals(2, sample(q.poll(60_000_000)!!))
    }
    @Test fun shortBurstStartsAfterSixtyMs() {
        val q = VoiceJitterBuffer(); q.offer(frame(7), 1, 0)
        assertNull(q.poll(59_000_000)); assertEquals(7, sample(q.poll(60_000_000)!!))
    }
    @Test fun staleSpeechIsNeverReplayed() {
        val q = VoiceJitterBuffer(); q.offer(frame(7), 1, 0)
        assertNull(q.poll(161_000_000))
    }
    @Test fun burstBufferHasHardLimit() {
        val q = VoiceJitterBuffer()
        for (n in 0..99) q.offer(frame(n), n, 0)
        assertEquals(94, sample(q.poll(0)!!))
        for (n in 95..99) assertEquals(n, sample(q.poll(0)!!))
        assertNull(q.poll(0))
    }
    @Test fun duplicateAndOutOfOrderFramesAreRejected() {
        val q = VoiceJitterBuffer(); assertTrue(q.offer(frame(1), 7, 0))
        assertFalse(q.offer(frame(2), 7, 0)); assertFalse(q.offer(frame(3), 6, 0))
        assertFalse(q.offer(frame(4), -1, 0)); assertFalse(q.offer(ByteArray(638), 8, 0))
    }
    @Test fun resetDropsSpeechAndAllowsNewSequence() {
        val q = VoiceJitterBuffer(); q.offer(frame(1), 999, 0); q.clear()
        assertNull(q.poll(0)); assertTrue(q.offer(frame(2), 0, 0))
    }
    @Test fun incomingBufferIsCopied() {
        val q = VoiceJitterBuffer(); val input = frame(123); q.offer(input, 1, 0)
        input.fill(0); assertEquals(123, sample(q.poll(60_000_000)!!))
    }
    @Test fun captureQueueKeepsNewestThreeFrames() {
        val q = CapturedFrames(); for (i in 0..99) q.offer(frame(i), 0)
        assertEquals(listOf(97,98,99), q.drain(0).map { sample(it) }); assertTrue(q.drain(0).isEmpty())
    }
    @Test fun captureDropsOldFramesAfterRenderStall() {
        val q = CapturedFrames(); q.offer(frame(1), 0); q.offer(frame(2), 110_000_000)
        assertEquals(listOf(2), q.drain(110_000_000).map { sample(it) })
    }
    @Test fun captureResetAndInvalidFrames() {
        val q = CapturedFrames(); q.offer(frame(7), 0); q.clear()
        q.offer(ByteArray(10), 0); assertTrue(q.drain(0).isEmpty())
    }
    @Test fun silenceAndNoiseAreNotAmplified() {
        val n = Pcm16Normalizer()
        val silence = frame(0); n.process(silence); assertArrayEquals(frame(0), silence)
        val noise = frame(100); repeat(100) { n.process(noise) }; assertEquals(100, sample(noise))
    }
    @Test fun quietSpeechGetsBoundedGain() {
        val n = Pcm16Normalizer(); var last = 0
        repeat(100) { val bytes = frame(1000); n.process(bytes); last = sample(bytes) }
        assertTrue(last in 2400..2500)
    }
    @Test fun peakLimiterPreventsClippingAndSignWrapping() {
        val n = Pcm16Normalizer(); repeat(50) { n.process(frame(1000)) }
        val loud = frame(32767); n.process(loud); assertTrue(sample(loud) in 0..30000)
        val negative = frame(-32768); n.process(negative); assertTrue(sample(negative) in -30000..0)
    }
    @Test fun littleEndianSignedSamplesStayCorrect() {
        val n = Pcm16Normalizer(); val bytes = frame(-100)
        n.process(bytes); assertEquals(-100, sample(bytes))
    }
}
