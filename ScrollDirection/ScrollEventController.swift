import AppKit
import CoreGraphics
import Foundation

protocol ScrollEventControlling: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop()
}

enum ScrollEventControllerError: LocalizedError {
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var errorDescription: String? {
        switch self {
        case .eventTapCreationFailed:
            "无法创建输入事件监听器。"
        case .runLoopSourceCreationFailed:
            "无法连接输入事件监听器与主运行循环。"
        }
    }
}

nonisolated enum ScrollEventTapKind: Equatable {
    case gesture
    case scrollWheel
}

nonisolated protocol ScrollEventTapResource: AnyObject {
    var isEnabled: Bool { get }
    func install()
    func enable()
    func invalidate()
}

private final class SystemScrollEventTapResource: ScrollEventTapResource {
    private let eventTap: CFMachPort
    private let runLoopSource: CFRunLoopSource
    private var isInstalled = false
    private var isInvalidated = false

    var isEnabled: Bool {
        !isInvalidated && CGEvent.tapIsEnabled(tap: eventTap)
    }

    init(
        kind: ScrollEventTapKind,
        userInfo: UnsafeMutableRawPointer
    ) throws {
        let eventTap: CFMachPort?
        switch kind {
        case .gesture:
            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(
                    NSEvent.EventTypeMask.gesture.rawValue
                ),
                callback: gestureEventTapCallback,
                userInfo: userInfo
            )
        case .scrollWheel:
            let eventMask = CGEventMask(1)
                << CGEventType.scrollWheel.rawValue
            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: scrollEventTapCallback,
                userInfo: userInfo
            )
        }

        guard let eventTap else {
            throw ScrollEventControllerError.eventTapCreationFailed
        }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            throw ScrollEventControllerError.runLoopSourceCreationFailed
        }
        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
    }

    func install() {
        guard !isInstalled, !isInvalidated else { return }
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            runLoopSource,
            .commonModes
        )
        isInstalled = true
        enable()
    }

    func enable() {
        guard !isInvalidated else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        if isInstalled {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )
            isInstalled = false
        }
        CFMachPortInvalidate(eventTap)
        isInvalidated = true
    }

    deinit {
        invalidate()
    }
}

private func gestureEventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let controller = scrollEventController(from: userInfo) else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        controller.enableGestureEventTap()
        return Unmanaged.passUnretained(event)
    }

    controller.handleGestureEvent(event)
    return Unmanaged.passUnretained(event)
}

private func scrollEventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let controller = scrollEventController(from: userInfo) else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        controller.enableScrollEventTap()
        return Unmanaged.passUnretained(event)
    }

    guard type == .scrollWheel else {
        return Unmanaged.passUnretained(event)
    }
    controller.handleScrollEvent(event)
    return Unmanaged.passUnretained(event)
}

private func scrollEventController(
    from userInfo: UnsafeMutableRawPointer?
) -> ScrollEventController? {
    guard let userInfo else { return nil }
    return Unmanaged<ScrollEventController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
}

final class ScrollEventController: ScrollEventControlling {
    typealias EventTapFactory = (
        ScrollEventTapKind,
        UnsafeMutableRawPointer
    ) throws -> any ScrollEventTapResource

    private let eventTapFactory: EventTapFactory
    private var gestureEventTap: (any ScrollEventTapResource)?
    private var scrollEventTap: (any ScrollEventTapResource)?
    private var sourceClassifier = ScrollSourceClassifier()

    var isRunning: Bool {
        guard let gestureEventTap, let scrollEventTap else {
            return false
        }
        return gestureEventTap.isEnabled && scrollEventTap.isEnabled
    }

    init(
        eventTapFactory: @escaping EventTapFactory = { kind, userInfo in
            try SystemScrollEventTapResource(
                kind: kind,
                userInfo: userInfo
            )
        }
    ) {
        self.eventTapFactory = eventTapFactory
    }

    func start() throws {
        precondition(Thread.isMainThread)
        if isRunning { return }
        stop()

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        do {
            let gestureEventTap = try eventTapFactory(
                .gesture,
                userInfo
            )
            self.gestureEventTap = gestureEventTap
            let scrollEventTap = try eventTapFactory(
                .scrollWheel,
                userInfo
            )
            self.scrollEventTap = scrollEventTap
            gestureEventTap.install()
            scrollEventTap.install()
        } catch {
            tearDown()
            throw error
        }
    }

    func stop() {
        precondition(Thread.isMainThread)
        tearDown()
    }

    func recordGesture(
        touchingCount: Int,
        gesturePhase: NSEvent.Phase,
        timestamp: CGEventTimestamp
    ) {
        sourceClassifier.recordGesture(
            touchingCount: touchingCount,
            gesturePhase: gesturePhase,
            timestamp: timestamp
        )
    }

    func classifyScroll(
        timestamp: CGEventTimestamp,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase
    ) -> ScrollSource {
        sourceClassifier.classifyScroll(
            timestamp: timestamp,
            phase: phase,
            momentumPhase: momentumPhase
        )
    }

    static func transformScrollEvent(
        _ event: CGEvent,
        source: ScrollSource
    ) {
        guard source == .mouse else { return }
        VerticalScrollDelta(event: event).inverted.write(to: event)
    }

    fileprivate func enableGestureEventTap() {
        gestureEventTap?.enable()
    }

    fileprivate func enableScrollEventTap() {
        scrollEventTap?.enable()
    }

    fileprivate func handleGestureEvent(_ event: CGEvent) {
        guard let appKitEvent = NSEvent(cgEvent: event) else { return }
        let touchingCount = appKitEvent.touches(
            matching: .touching,
            in: nil
        ).count
        recordGesture(
            touchingCount: touchingCount,
            gesturePhase: Self.gesturePhase(
                in: appKitEvent,
                touchingCount: touchingCount
            ),
            timestamp: event.timestamp
        )
    }

    fileprivate func handleScrollEvent(_ event: CGEvent) {
        let appKitEvent = NSEvent(cgEvent: event)
        let source = classifyScroll(
            timestamp: event.timestamp,
            phase: appKitEvent?.phase ?? [],
            momentumPhase: appKitEvent?.momentumPhase ?? []
        )
        Self.transformScrollEvent(event, source: source)
    }

    private static func gesturePhase(
        in event: NSEvent,
        touchingCount: Int
    ) -> NSEvent.Phase {
        if !event.touches(matching: .cancelled, in: nil).isEmpty {
            return .cancelled
        }
        if touchingCount == 0
            && !event.touches(matching: .ended, in: nil).isEmpty {
            return .ended
        }
        if !event.touches(matching: .began, in: nil).isEmpty {
            return .began
        }
        if touchingCount > 0 {
            return .changed
        }
        return []
    }

    private func tearDown() {
        scrollEventTap?.invalidate()
        gestureEventTap?.invalidate()
        scrollEventTap = nil
        gestureEventTap = nil
        sourceClassifier = ScrollSourceClassifier()
    }

    deinit {
        tearDown()
    }
}
