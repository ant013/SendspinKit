# Isolated LTE clock experiment — revision 1

Status: ready for owner review; implementation has not started.
Branch: `experiment/lte-clock-rtt` in the operator fork `ant013/SendspinKit`.
Base: upstream `main`, revision `4554968a469f7dcbbdc41ee1d0419969ecf6fe33`.
No develop branch exists. The original remote and pinned comparison are preserved.

## Goal and assumptions

Determine whether the native Sendspin client can produce an accurate clock model
and actual synchronous output over the measured LTE/public-WSS route. The existing
short LAN comparison needed a36 ms relative POCO output correction and measured
about1 ms residual. The same native output implementations, speaker routes and
PCM format must remain in place to reuse that correction. It is not a universal
hardware constant or an Internet-delay correction.

The previous native LTE trial connected and the server received21 clock requests,
but no clock sample was accepted. Separate application echo measured204–219 ms RTT.
The current synchronizer rejects RTT above100 ms. Its public telemetry is nil
until initialization, so the exact rejected clock RTT has not been observed.

Success means measurable, reproducible output alignment; merely accepting a
high-RTT sample, connecting, or obtaining small filter sigma is not success.
Master-immediate/count-in behavior and the Gig application remain unchanged.

## Scope and affected areas

1. `Sources/SendspinKit/Synchronization/ClockSynchronizer.swift`: retain100 ms
   default; add an internal, construction-time bench opt-in selecting1000 ms.
   Read the opt-in only from `SENDSPIN_BENCH_HIGH_RTT=1`, default off, with an
   explicit internal initializer argument for deterministic tests. Do not allow
   arbitrary unbounded limits or mutate a live clock's policy.
2. The same file: optional `SENDSPIN_BENCH_CLOCK_DIAGNOSTICS=1` logs the computed
   raw RTT, effective ceiling and rejection before initialization. Public
   diagnosticSnapshot/currentClockSyncStats continue returning nil until valid
   filter initialization. Do not log secrets or audio data.
3. `Sources/SendspinKit/Client/ClockSyncStats.swift`: qualify the100 ms statement
   as the default policy. No public shape/API changes or invented uncertainty.
4. Add `Tests/SendspinKitTests/Synchronization/ClockSynchronizerRttPolicyTests.swift`.
5. External standalone host/controller under `../IOSBench` and `../run_pcm_bench.py`:
   forward explicit experiment flags, label/hashes for the variant, parse raw
   diagnostics, and keep separate control/experiment reports. No Gig source or
   device library data changes; no upstream PR or merges.

## Preserved invariants and rejected changes

Keep all overflow/negative-RTT rejection, monotonic filtering, per-connection clock
ownership, timestamp conventions, audio engine, output latency handling, cadence,
and Kalman parameters. Feed the ACTUAL RTT/2 into the existing filter, including
its existing maxErrorScale. Never clamp a200 ms exchange to100 ms to manufacture
confidence. Keep no-data state unknown. Do not change probe cadence in this first
experiment, hardcode36 ms in a product, or declare green from server availability.

## Analog delta matrix

| Field | S-RTT: clock policy and startup evidence |
|---|---|
| Primary family | Existing ClockSynchronizer overflow-checked four-timestamp path |
| Supporting roles | SendspinClient per-connection composition; WireTimestampOverflowTests and ClockSynchronizerTests as test seams |
| Counterexample | Public initialized-only diagnostics cannot represent startup rejection; reject fake initialized stats |
| Coverage | Contract, implementation, composition, consumer, lifecycle/error, tests and counterexample checked in current tree; no role waivers |
| Required difference | Explicit bench-only1000 ms ceiling plus raw rejection logs before initialization |
| Rejected difference | Global release-policy change, altered filter uncertainty, alternate player, faster probe cadence, and product integration |
| Failure modes | No samples, malformed arithmetic, excessive RTT, changed output route, stale model, asynchronous cleanup, or network path asymmetry |
| Tests before change | A valid400 ms symmetric exchange is currently rejected; capture that behavior as the control and make opt-in tests fail before policy implementation |
| Verification | Narrow policy/overflow/filter tests, strict formatting/lint, timed pool/package suite, signed native host, silent LTE A/B and conditional acoustic capture |

## Test plan

Use explicit injected policies in unit tests; do not mutate process environment
across concurrent tests. Cover default100 ms boundary and rejection above it,
opt-in400 ms acceptance,1000 ms boundary and rejection above it, negative RTT,
Int64 overflow, and rejection after a valid sample without corrupting the model.
Compare opt-in uncertainty with the same filter fed the actual measurement so
raising the acceptance ceiling cannot silently reduce the noise supplied to it.
Existing conversion and initialized-only snapshot behavior must remain valid.

Before every Swift commit run changed-file `swiftformat --lint` and
`swiftlint lint --strict`. swiftlint is currently unavailable and must be installed
or the mandatory gate remains pending. Run narrow tests and the repository's
`scripts/strict-pool-test.sh` under explicit timeouts, then the affected package
suite under a timeout. Tests starting real audio remain opt-in. No public API is
planned; if that changes, run scripts/build-examples.sh and return to design review.

## Device experiment and acceptance

First run the patched build with diagnostics ON and high RTT OFF, silently:
confirm actual clock RTT/rejections and reproduce the initial no-clock condition.
Then restart the same build with high RTT ON, still silently. Record accepted
count, actual RTT, sigma, drift, offset changes, path type and route diagnostics.
Wait at most600 seconds for a usable model. Keep progress visible and clients
awake while waiting. Unavailable devices remain pending; continue independent
checks instead of repeatedly rerunning passing tests.

For an audible trial require fresh finite stats, at least8 accepted samples,
nominal estimated sigma <=5 ms for5 seconds, coherent server timeline and confirmed
unchanged speaker route. This sigma is a statistical admission heuristic, not a
worst-case guarantee: stable asymmetric paths can bias offset despite low sigma.
If the model does not qualify within the bounded wait, report CLOCK_UNCERTAIN and
start no sound. Do not weaken the threshold just to obtain a recording.

Verify the existing POCO36 ms output correction is acknowledged and unchanged.
Only then run the existing27-second native microphone comparison: iPhone-only,
both, POCO-only. Retain exactly1,296,000 frames at48 kHz and explicitly contiguous
PCM source timestamps. Stop/mute on route/network loss or invalid clock data.
Always stop stream, server and clients after the experiment, including failure.

Acoustic result <=10 ms is a short trial pass; >15 ms is a failure and must not be
hidden by additional manual fitting over LTE. Values between10 and15 ms are not
admission success. No data, one inaudible phone, or invalid capture is unqualified.
Even a short pass does not qualify reconnects, arbitrary devices, all network
routes or long-duration performance. Record startup delay independently: several
minutes to settle would not satisfy the intended count-in catch-up experience.

## Adversarial decisions

D-SMALLER: no public clock override exists; latest upstream main has the same
fixed limit. A nearer server is preferable for transport latency, but changing
routes would not test the currently observed failure. Keep the experiment bounded.
D-QUALITY: increasing the ceiling cannot prove true clock accuracy. Preserve
actual RTT-derived noise and unknown state; require microphone evidence and do
not transfer a statistical sigma into a worst-case product guarantee.
D-SCOPE: this is a clearly labeled operator fork, not an unchanged-SDK result or
production fix. Default behavior stays100 ms; no changes to Gig or Android SDK.
D-LIFECYCLE: do not write multiple live consoles into one truncated pathname;
unlink the previous log before launch and seal its hash only after stopping it.

All four design decisions accept this bounded revision; none approve deployment.

## Open questions and review gate

No routine technical choices remain open. Owner approval is required for this
written experimental fork design before SDK implementation, as required by the
applicable analog-driven-change skill. The broader Gig synchronization task and
microphone permission remain authorized; this gate concerns the third-party
library delta only. A materially different design requires fresh review.
