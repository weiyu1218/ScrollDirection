import Testing
@testable import ScrollDirection

struct VerticalScrollDeltaTests {
    @Test
    func inversionChangesAllVerticalRepresentations() {
        let delta = VerticalScrollDelta(line: 3, fixedPoint: 3.5, point: 30)

        #expect(
            delta.inverted
                == VerticalScrollDelta(line: -3, fixedPoint: -3.5, point: -30)
        )
    }

    @Test
    func inversionPreservesZero() {
        let delta = VerticalScrollDelta(line: 0, fixedPoint: 0, point: 0)

        #expect(
            delta.inverted
                == VerticalScrollDelta(line: 0, fixedPoint: 0, point: 0)
        )
    }
}
