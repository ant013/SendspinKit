@testable import SendspinKit
import Testing

struct ClockSynchronizerRttPolicyTests {
    private let clientBase: Int64 = 1_000_000
    private let serverOffset: Int64 = 10_000
    private let serverProcessing: Int64 = 1_000
    private let slowRtt: Int64 = 400_000

    @Test(arguments: [false, true])
    func ceilingIsInclusiveAndRejectsTheNextMicrosecond(allowHighRtt: Bool) async {
        let limit = allowHighRtt
            ? ClockSynchronizer.benchMaximumRttMicroseconds
            : ClockSynchronizer.defaultMaximumRttMicroseconds
        let clock = ClockSynchronizer(allowHighRttForBench: allowHighRtt, benchDiagnosticsEnabled: false)
        await feed(clock, rtt: limit)
        #expect(await clock.totalSamplesAccepted == 1)
        #expect(await clock.latestAcceptedRtt == limit)

        let rejectedClock = ClockSynchronizer(allowHighRttForBench: allowHighRtt, benchDiagnosticsEnabled: false)
        await feed(rejectedClock, rtt: limit + 1)
        #expect(await rejectedClock.totalSamplesAccepted == 0)
        #expect(await rejectedClock.lastSampleWasRejected)
        #expect(await rejectedClock.diagnosticSnapshot() == nil)
        #expect(await rejectedClock.snapshot() == nil)
    }

    @Test
    func defaultRejectsTheMeasuredClassOfSlowExchange() async {
        let clock = ClockSynchronizer(allowHighRttForBench: false, benchDiagnosticsEnabled: false)
        await feed(clock, rtt: slowRtt)
        #expect(await clock.latestRawRtt == slowRtt)
        #expect(await clock.lastSampleWasRejected)
        #expect(await clock.totalSamplesAccepted == 0)
        #expect(await clock.hasSynced == false)
    }

    @Test
    func optInAcceptsSlowExchangeWithItsActualMeasurementNoise() async throws {
        let clock = ClockSynchronizer(allowHighRttForBench: true, benchDiagnosticsEnabled: false)
        await feed(clock, rtt: slowRtt)
        let diagnostic = try #require(await clock.diagnosticSnapshot())
        var reference = SendspinTimeFilter()
        reference.update(
            timeAdded: clientBase + slowRtt + serverProcessing,
            measurement: Double(serverOffset),
            maxError: Double(slowRtt) / 2
        )
        #expect(diagnostic.rtt == slowRtt)
        #expect(diagnostic.offset == serverOffset)
        #expect(diagnostic.sampleCount == 1)
        #expect(diagnostic.rawRttWasRejected == false)
        #expect(diagnostic.estimatedError == reference.estimatedError)
        #expect(await clock.hasSynced == false)
        #expect(await clock.snapshot() == nil)
        await feed(clock, rtt: slowRtt, start: clientBase + 2_000_000)
        #expect(await clock.hasSynced)
        #expect(await clock.snapshot() != nil)
    }

    @Test(arguments: [false, true])
    func negativeAndOverflowedExchangesRemainRejected(allowHighRtt: Bool) async {
        let clock = ClockSynchronizer(allowHighRttForBench: allowHighRtt, benchDiagnosticsEnabled: false)
        await clock.processServerTime(
            clientTransmitted: clientBase, serverReceived: clientBase,
            serverTransmitted: clientBase + serverProcessing, clientReceived: clientBase
        )
        #expect(await clock.latestRawRtt == -serverProcessing)
        #expect(await clock.lastSampleWasRejected)
        await clock.processServerTime(
            clientTransmitted: .min, serverReceived: .max, serverTransmitted: .min, clientReceived: .max
        )
        #expect(await clock.lastSampleWasRejected)
        #expect(await clock.totalSamplesAccepted == 0)
        #expect(await clock.diagnosticSnapshot() == nil)
    }

    @Test
    func rejectedOutlierDoesNotCorruptAnAcceptedModel() async throws {
        let clock = ClockSynchronizer(allowHighRttForBench: true, benchDiagnosticsEnabled: false)
        await feed(clock, rtt: slowRtt)
        let before = try #require(await clock.diagnosticSnapshot())
        let outlier = ClockSynchronizer.benchMaximumRttMicroseconds + 1
        await feed(clock, rtt: outlier, start: clientBase + 2_000_000)
        let after = try #require(await clock.diagnosticSnapshot())
        #expect(after.sampleCount == before.sampleCount)
        #expect(after.offset == before.offset)
        #expect(after.rtt == before.rtt)
        #expect(after.estimatedError == before.estimatedError)
        #expect(after.rawRtt == outlier)
        #expect(after.rawRttWasRejected)
    }

    private func feed(_ clock: ClockSynchronizer, rtt: Int64, start: Int64? = nil) async {
        let transmitted = start ?? clientBase
        let received = transmitted + rtt / 2 + serverOffset
        await clock.processServerTime(
            clientTransmitted: transmitted,
            serverReceived: received,
            serverTransmitted: received + serverProcessing,
            clientReceived: transmitted + rtt + serverProcessing
        )
    }
}
