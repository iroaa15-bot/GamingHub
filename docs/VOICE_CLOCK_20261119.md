# PCM mixer cadence regression

The owner reports weak/unclear audio in both directions during a real two-phone
Open Heart room on the local Windows endpoint. This is a failed audible result,
even though mutual consent, capture and receive counters were active.

Each server packet carries 320 mono 16-bit samples at 16kHz (20ms). The mixer
previously waited a fresh 20ms after each iteration. On this Windows host, a
150-iteration probe took 4.716s: 31.81 packets/s, leaving playback without enough
samples. Scheduler rounding plus mixing/send work accumulates each iteration.
This is a plausible contribution to choppiness; it does not prove that every
volume or hardware problem has been identified.

The new clock waits for successive deadlines. It recovers small oversleeps and
includes processing time in the frame budget. After a stall greater than 40ms it
rebases, preventing an unbounded catch-up burst. The same host measured 3.012s for
150 iterations: 49.8 packets/s. Four deterministic tests cover quantized Windows
wakes, processing overhead, long stalls and small oversleep. Membership/consent
security tests also pass.

No PCM content or speech is recorded. No native gain, routing, AEC/NS/AGC, consent,
room scoring or production configuration changes. This is a separate draft from
the UI redesign, based on PR #21 at 63cafe4. Local phone retest is still required;
no claim of audible resolution, notification acceptance or Play readiness.
