import Testing
@testable import ScrollDirection

struct ScrollSourceTests {
    @Test
    func zeroContinuousValueIsMouse() {
        #expect(ScrollSource.classify(continuousValue: 0) == .mouse)
    }

    @Test
    func nonzeroContinuousValueIsTrackpad() {
        #expect(ScrollSource.classify(continuousValue: 1) == .trackpad)
        #expect(ScrollSource.classify(continuousValue: -1) == .trackpad)
    }
}
