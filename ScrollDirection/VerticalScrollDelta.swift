import CoreGraphics

nonisolated struct VerticalScrollDelta: Equatable {
    let line: Int64
    let fixedPoint: Double
    let point: Int64

    init(line: Int64, fixedPoint: Double, point: Int64) {
        self.line = line
        self.fixedPoint = fixedPoint
        self.point = point
    }

    init(event: CGEvent) {
        line = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        fixedPoint = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        point = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    }

    var inverted: VerticalScrollDelta {
        VerticalScrollDelta(
            line: -line,
            fixedPoint: -fixedPoint,
            point: -point
        )
    }

    func write(to event: CGEvent) {
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: line)
        event.setDoubleValueField(
            .scrollWheelEventFixedPtDeltaAxis1,
            value: fixedPoint
        )
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: point)
    }
}
