import asyncio
import math
import time
import unittest
from voice_frame_clock import VoiceFrameClock


class FrameClockTests(unittest.TestCase):
    def test_quantized_windows_wait_does_not_lose_a_third_of_pcm(self):
        now=0.0
        clock=VoiceFrameClock(now)
        for _ in range(150):
            delay=clock.delay(now)
            now += math.ceil(delay*64-1e-9)/64
        self.assertAlmostEqual(now,3.0,delta=1/64)

    def test_processing_time_is_part_of_frame_budget(self):
        now=0.0
        clock=VoiceFrameClock(now)
        for _ in range(150):
            now += clock.delay(now) + .003
        self.assertAlmostEqual(now,3.003,places=6)

    def test_long_stall_rebases_instead_of_replaying_backlog(self):
        clock=VoiceFrameClock(0)
        self.assertAlmostEqual(clock.delay(2.0),.02)
        self.assertAlmostEqual(clock.delay(2.02),.02)

    def test_small_oversleep_is_recovered_without_negative_wait(self):
        clock=VoiceFrameClock(0)
        self.assertEqual(clock.delay(.03125),0)
        self.assertAlmostEqual(clock.delay(.03125),.00875)


if __name__=='__main__':unittest.main()
