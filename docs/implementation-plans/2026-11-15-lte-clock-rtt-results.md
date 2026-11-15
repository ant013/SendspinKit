# LTE clock experiment — implementation and verification

Implementation: `8a1f6d3`, branch `experiment/lte-clock-rtt` in `ant013/SendspinKit`.
Design revision1 was explicitly approved by the owner before SDK source changes.

## Implemented delta

ClockSynchronizer retains its100 ms default. An explicitly enabled bench flag
selects1000 ms at construction; deterministic tests inject the same boolean.
An independent bench diagnostic flag logs actual raw RTT/rejection even before
initialization. Public initialized-only statistics and the filter's real
RTT-derived measurement noise remain unchanged. Arithmetic/negative-RTT guards,
probe cadence and native audio paths are preserved. ClockSyncStats documentation
identifies the default policy; no public API shape changed.

The external native host/controller label this fork, record its revision/source
hash, validate LTE/speaker/output timing, and wait at most600 seconds for at least
8 accepted samples and nominal sigma <=5 ms continuously for5 seconds. Stale,
invalid, changed-route/network and muted-output conditions block the microphone
trial; checks continue during playback and the host can mute locally. This is
an experimental statistical admission heuristic, not a true-error guarantee.

## Automated evidence

- An isolated executable compiled from the real clock/filter sources reproduced
  the original failure for a valid400 ms symmetric exchange with opt-in requested:
  accepted=0, rejected=true. After the patch, the same exchange gives accepted=1,
  rejected=false, raw RTT400000, limit1000000.
-44 targeted clock/policy/filter/overflow tests passed.
-1149 package tests in121 suites passed.
-1149 tests also passed with LIBDISPATCH_COOPERATIVE_POOL_STRICT=1.
- The required strict-pool script initially failed to load XCTest.framework before
  tests started. Using GNU timeout and an explicit Xcode SharedFrameworks fallback
  ran the unmodified script successfully:1149 passed, zero issues, exit0.
- Changed-file SwiftFormat lint and strict SwiftLint: zero violations.
- Signed Release iOS host build passed and was installed on the same iPhone.
- `python3 verify_clock_guard.py` passes stable admission, stale/noisy/nonfinite
  statistics, wrong policy/network, changed routes/timing, zero volume and resets.

Commands (each test execution bounded):

```sh
timeout 600 swift build --build-tests
timeout 30 swift test --skip-build --filter 'ClockSynchronizerRttPolicyTests|WireTimestampOverflowTests|ClockSynchronizerTests|SendspinTimeFilterTests'
timeout 30 swift test --skip-build
timeout 30 env LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 swift test --skip-build
# In a shell, export DYLD_FALLBACK_FRAMEWORK_PATH to the Xcode Contents/SharedFrameworks
# directory, put Homebrew coreutils/gnubin first in PATH, then source:
scripts/strict-pool-test.sh lte-rtt-gnu
```

## Physical LTE control

The same build ran with diagnostics enabled and high RTT disabled. iPhone logs
confirmed cellular=1/wifi=0, built-in Speaker,12.375 ms reported output latency and
21.333 ms I/O buffer. All21 clock samples were rejected by the100000 us limit;
actual raw RTT ranged213.008–339.783 ms. The previous explanation is now directly
confirmed, rather than inferred from a separate application echo. No audio ran.

## Physical high-RTT trial

The opt-in run accepted618 raw clock samples with RTT216.457–873.563 ms
(median239.338 ms). The nominal sigma admission required583.585 seconds of quiet
qualification, following connection setup. This startup is unsuitable for count-in
catch-up; the experiment only demonstrates eventual short-run alignment.

After the5-second qualification hold, the controller verified POCO output delay36 ms
and iPhone0 ms, then recorded27 seconds /1,296,000 frames at48 kHz with the native
recorder. Both separate-phone phases contain the reference chirps, with normalized
correlation0.503/0.242. Their relative lag estimate is-0.375 ms (POCO slightly earlier).
The combined phase has a merged dominant arrival at-1.125 ms relative to the earlier
iPhone-only reference. Seven overlapping2-second windows have dominant arrivals
between-1.5 and+1.0 ms; responses at least15 ms from each main arrival are below8.3%
of its amplitude. These are acoustic estimates, not calibrated loopback guarantees.

During capture,14 clock snapshots report nominal sigma4.795–4.938 ms; accepted
count advances591–617. No safety mute was triggered. The fixed LAN output correction
was not retuned for LTE. The short acoustic trial meets the10 ms threshold for this
pair and route, approximately1–2 ms observed, while broader product qualification
and fast startup remain unmet. Sound, both clients and the temporary tunnel stopped.

Final artifacts: `wan-rtt-result.json`, `wan-rtt-experiment-comparison.json`,
`wan-rtt-experiment.caf`, `wan-rtt-experiment-arrivals.png`, `wan-rtt-clock.png` and
`wan-rtt-control.json`. Capture SHA256:
`8c0220168eeea21ef8fd1032025595e94d147520c000119d688cd619f28714cc`.

## Evidence and limits

Local standalone artifacts are under the operator's
`jazzfriends-multiplayer/experiments/sendspin-bench` directory: control and
experiment JSON/logs, `bench_clock_guard.py`, `verify_clock_guard.py`, native host
and signed build. They are not source copies in audit/runs. The workflow record
and generated Gimle report remain in the canonical skill audit directory.

Gimle trust: YELLOW. Gimle/Palace and Serena are unavailable; codebase-memory has
no indexed projects. Load-bearing facts were verified from pinned/current Git,
targeted source reads, tests and physical native diagnostics. No Gimle result
was fabricated or relied on.

Even eventual low sigma does not identify fixed network-path asymmetry. The36 ms
POCO correction belongs to the existing native pair/routes and must not be tuned
to fit the LTE result. Long startup, arbitrary routes/devices, reconnects and
long-duration audio remain separate acceptance questions. Nothing here claims
that Gig has achieved Internet audible synchronization.
