nonisolated enum ScrollSource: Equatable {
    case mouse
    case trackpad

    static func classify(continuousValue: Int64) -> ScrollSource {
        continuousValue == 0 ? .mouse : .trackpad
    }
}
