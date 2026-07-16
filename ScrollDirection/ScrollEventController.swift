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
            "无法创建滚动事件过滤器。"
        case .runLoopSourceCreationFailed:
            "无法连接滚动事件过滤器与主运行循环。"
        }
    }
}

private func scrollEventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let controller = Unmanaged<ScrollEventController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let eventTap = controller.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .scrollWheel else {
        return Unmanaged.passUnretained(event)
    }
    ScrollEventController.transformScrollEvent(event)
    return Unmanaged.passUnretained(event)
}

final class ScrollEventController: ScrollEventControlling {
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() throws {
        precondition(Thread.isMainThread)
        if isRunning { return }
        stop()

        let eventMask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: scrollEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
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
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        precondition(Thread.isMainThread)
        tearDown()
    }

    static func transformScrollEvent(_ event: CGEvent) {
        let continuousValue = event.getIntegerValueField(
            .scrollWheelEventIsContinuous
        )
        guard ScrollSource.classify(continuousValue: continuousValue) == .mouse
        else {
            return
        }
        VerticalScrollDelta(event: event).inverted.write(to: event)
    }

    private func tearDown() {
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    deinit {
        tearDown()
    }
}
