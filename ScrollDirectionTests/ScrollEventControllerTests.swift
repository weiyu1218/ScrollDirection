import AppKit
import CoreGraphics
import Testing
@testable import ScrollDirection

@MainActor
struct ScrollEventControllerTests {
    @Test
    func mouseEventInvertsVerticalFieldsAndPreservesHorizontalFields() throws {
        let event = try makeEvent()
        event.setIntegerValueField(
            .scrollWheelEventIsContinuous,
            value: 1
        )

        ScrollEventController.transformScrollEvent(event, source: .mouse)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -3.5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -30)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 4)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) == 4.5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 40)
    }

    @Test
    func trackpadEventIsUnchanged() throws {
        let event = try makeEvent()
        event.setIntegerValueField(
            .scrollWheelEventIsContinuous,
            value: 0
        )
        let verticalBefore = VerticalScrollDelta(event: event)
        let horizontalLineBefore = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let horizontalFixedBefore = event.getDoubleValueField(
            .scrollWheelEventFixedPtDeltaAxis2
        )
        let horizontalPointBefore = event.getIntegerValueField(
            .scrollWheelEventPointDeltaAxis2
        )

        ScrollEventController.transformScrollEvent(event, source: .trackpad)

        #expect(VerticalScrollDelta(event: event) == verticalBefore)
        #expect(
            event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
                == horizontalLineBefore
        )
        #expect(
            event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
                == horizontalFixedBefore
        )
        #expect(
            event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
                == horizontalPointBefore
        )
    }

    @Test
    func gestureWithFewerThanTwoTouchesDoesNotEstablishTrackpadEvidence() {
        let controller = ScrollEventController()

        controller.recordGesture(
            touchingCount: 1,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )

        #expect(
            controller.classifyScroll(
                timestamp: 1_000_000_001,
                phase: [],
                momentumPhase: []
            ) == .mouse
        )
    }

    @Test
    func gestureWithTwoTouchesEstablishesTrackpadEvidence() {
        let controller = ScrollEventController()

        controller.recordGesture(
            touchingCount: 2,
            gesturePhase: .began,
            timestamp: 1_000_000_000
        )

        #expect(
            controller.classifyScroll(
                timestamp: 1_000_000_001,
                phase: [],
                momentumPhase: []
            ) == .trackpad
        )
    }

    @Test
    func stopReleasesGestureAndScrollEventTapResources() throws {
        let gestureResource = FakeEventTapResource()
        let scrollResource = FakeEventTapResource()
        var createdKinds: [ScrollEventTapKind] = []
        let controller = ScrollEventController(
            eventTapFactory: { kind, _ in
                createdKinds.append(kind)
                switch kind {
                case .gesture:
                    return gestureResource
                case .scrollWheel:
                    return scrollResource
                }
            }
        )

        try controller.start()
        controller.stop()

        #expect(createdKinds == [.gesture, .scrollWheel])
        #expect(gestureResource.installCallCount == 1)
        #expect(scrollResource.installCallCount == 1)
        #expect(gestureResource.invalidateCallCount == 1)
        #expect(scrollResource.invalidateCallCount == 1)
        #expect(!controller.isRunning)
    }

    private func makeEvent() throws -> CGEvent {
        let event = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 2,
                wheel1: 3,
                wheel2: 4,
                wheel3: 0
            )
        )
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 3)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 3.5)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 30)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 4)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 4.5)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 40)
        return event
    }
}

private final class FakeEventTapResource: ScrollEventTapResource {
    private(set) var isEnabled = false
    private(set) var installCallCount = 0
    private(set) var invalidateCallCount = 0

    func install() {
        installCallCount += 1
        isEnabled = true
    }

    func enable() {
        isEnabled = true
    }

    func invalidate() {
        invalidateCallCount += 1
        isEnabled = false
    }
}
