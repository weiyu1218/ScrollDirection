import AppKit
import CoreGraphics

nonisolated enum ScrollSource: Equatable {
    case mouse
    case trackpad
}

nonisolated struct ScrollSourceClassifier {
    private enum GestureState {
        case inactive
        case active(CGEventTimestamp)
        case recent(CGEventTimestamp)

        var timestamp: CGEventTimestamp? {
            switch self {
            case .inactive:
                nil
            case .active(let timestamp), .recent(let timestamp):
                timestamp
            }
        }
    }

    private static let gestureAssociationWindow: CGEventTimestamp =
        222_000_000

    private var gestureState: GestureState = .inactive
    private var lastSource: ScrollSource = .mouse

    mutating func recordGesture(
        touchingCount: Int,
        gesturePhase: NSEvent.Phase,
        timestamp: CGEventTimestamp
    ) {
        if gesturePhase.contains(.ended)
            || gesturePhase.contains(.cancelled) {
            gestureState = .inactive
            return
        }

        if touchingCount >= 2 {
            gestureState = .active(timestamp)
            return
        }

        if case .active(let timestamp) = gestureState {
            gestureState = .recent(timestamp)
        }
    }

    mutating func classifyScroll(
        timestamp: CGEventTimestamp,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase
    ) -> ScrollSource {
        let hasRecentTwoFingerGesture = isTwoFingerGestureRecent(
            at: timestamp
        )
        let hasFluidScrollPhase = !phase.isEmpty
        let continuesTrackpadMomentum = !momentumPhase.isEmpty
            && lastSource == .trackpad

        let source: ScrollSource = if hasRecentTwoFingerGesture
            || hasFluidScrollPhase
            || continuesTrackpadMomentum {
            .trackpad
        } else {
            .mouse
        }
        lastSource = source
        return source
    }

    private mutating func isTwoFingerGestureRecent(
        at timestamp: CGEventTimestamp
    ) -> Bool {
        guard let gestureTimestamp = gestureState.timestamp,
              timestamp >= gestureTimestamp else {
            return false
        }
        let isRecent = timestamp - gestureTimestamp
            < Self.gestureAssociationWindow
        if !isRecent {
            gestureState = .inactive
        }
        return isRecent
    }
}
