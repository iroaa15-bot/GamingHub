"""Deadline pacing for 20ms PCM; scheduler oversleep must not accumulate."""
import time


class VoiceFrameClock:
    interval = .02

    def __init__(self, now=None):
        self.deadline = time.perf_counter() if now is None else now

    def delay(self, now=None):
        now = time.perf_counter() if now is None else now
        self.deadline += self.interval
        # A long stall must not cause an unbounded catch-up burst of old speech.
        if now - self.deadline > 2 * self.interval:
            self.deadline = now + self.interval
        return max(0.0, self.deadline - now)
