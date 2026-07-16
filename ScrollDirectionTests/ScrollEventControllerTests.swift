import CoreGraphics
import Testing
@testable import ScrollDirection

struct ScrollEventControllerTests {
    @Test
    func mouseEventInvertsVerticalFieldsAndPreservesHorizontalFields() throws {
        let event = try makeEvent(continuousValue: 0)

        ScrollEventController.transformScrollEvent(event)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -3.5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -30)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 4)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) == 4.5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 40)
    }

    @Test
    func trackpadEventIsUnchanged() throws {
        let event = try makeEvent(continuousValue: 1)
        let verticalBefore = VerticalScrollDelta(event: event)
        let horizontalLineBefore = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let horizontalFixedBefore = event.getDoubleValueField(
            .scrollWheelEventFixedPtDeltaAxis2
        )
        let horizontalPointBefore = event.getIntegerValueField(
            .scrollWheelEventPointDeltaAxis2
        )

        ScrollEventController.transformScrollEvent(event)

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

    private func makeEvent(continuousValue: Int64) throws -> CGEvent {
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
        event.setIntegerValueField(
            .scrollWheelEventIsContinuous,
            value: continuousValue
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
