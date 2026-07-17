import AppKit
import Testing
@testable import ScrollDirection

struct ScrollSourceTests {
    @Test
    func noTrackpadEvidenceIsMouse() {
        var classifier = ScrollSourceClassifier()

        let source = classifier.classifyScroll(
            timestamp: 1_000_000_000,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .mouse)
    }

    @Test
    func activeTwoFingerGestureIsTrackpad() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_100_000_000,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .trackpad)
    }

    @Test
    func activeTwoFingerGestureExpiresWithoutFurtherGestureEvents() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_222_000_000,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .mouse)
    }

    @Test
    func recentTwoFingerGestureIsTrackpadAfterTouchCountDrops() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )
        classifier.recordGesture(
            touchingCount: 1,
            gesturePhase: .changed,
            timestamp: 1_010_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_221_999_999,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .trackpad)
    }

    @Test
    func oneFingerGestureDoesNotEstablishTrackpadEvidence() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 1,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_000_000_001,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .mouse)
    }

    @Test
    func endedGestureClearsTrackpadEvidenceImmediately() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )
        classifier.recordGesture(
            touchingCount: 0,
            gesturePhase: .ended,
            timestamp: 1_010_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_010_000_001,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .mouse)
    }

    @Test
    func cancelledGestureClearsTrackpadEvidenceImmediately() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )
        classifier.recordGesture(
            touchingCount: 0,
            gesturePhase: .cancelled,
            timestamp: 1_010_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_010_000_001,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .mouse)
    }

    @Test
    func expiredTwoFingerGestureIsMouse() {
        var classifier = ScrollSourceClassifier()
        classifier.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )
        classifier.recordGesture(
            touchingCount: 1,
            gesturePhase: .changed,
            timestamp: 1_010_000_000
        )

        let source = classifier.classifyScroll(
            timestamp: 1_222_000_000,
            phase: [],
            momentumPhase: []
        )

        #expect(source == .mouse)
    }

    @Test
    func fluidScrollPhaseIsTrackpad() {
        var classifier = ScrollSourceClassifier()

        let source = classifier.classifyScroll(
            timestamp: 1_000_000_000,
            phase: .began,
            momentumPhase: []
        )

        #expect(source == .trackpad)
    }

    @Test
    func momentumContinuesTrackpadSource() {
        var classifier = ScrollSourceClassifier()
        #expect(
            classifier.classifyScroll(
                timestamp: 1_000_000_000,
                phase: .began,
                momentumPhase: []
            ) == .trackpad
        )

        let source = classifier.classifyScroll(
            timestamp: 1_100_000_000,
            phase: [],
            momentumPhase: .changed
        )

        #expect(source == .trackpad)
    }

    @Test
    func momentumDoesNotChangeMouseSourceToTrackpad() {
        var classifier = ScrollSourceClassifier()

        let source = classifier.classifyScroll(
            timestamp: 1_000_000_000,
            phase: [],
            momentumPhase: .began
        )

        #expect(source == .mouse)
    }
}
