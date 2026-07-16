import Foundation
@testable import ScrollDirection

final class FakeScrollEventController: ScrollEventControlling {
    private(set) var isRunning = false
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var startError: Error?

    func start() throws {
        if isRunning { return }
        startCallCount += 1
        if let startError {
            throw startError
        }
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}

final class FakePermissionController: PermissionControlling {
    var statusValue: PermissionStatus
    private(set) var requestCallCount = 0
    private(set) var openSettingsCallCount = 0
    var openSettingsResult = true

    init(status: PermissionStatus) {
        statusValue = status
    }

    func currentStatus() -> PermissionStatus {
        statusValue
    }

    func requestMissingPermissions() {
        requestCallCount += 1
    }

    func openSystemSettings() -> Bool {
        openSettingsCallCount += 1
        return openSettingsResult
    }
}

final class FakeLoginItemController: LoginItemControlling {
    var status: LoginItemStatus
    private(set) var setEnabledCalls: [Bool] = []
    private(set) var openSettingsCallCount = 0
    var setEnabledError: Error?

    init(status: LoginItemStatus) {
        self.status = status
    }

    func setEnabled(_ enabled: Bool) throws {
        setEnabledCalls.append(enabled)
        if let setEnabledError {
            throw setEnabledError
        }
        status = enabled ? .enabled : .notRegistered
    }

    func openSystemSettings() {
        openSettingsCallCount += 1
    }
}

struct TestFailure: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

final class TemporaryDefaults {
    let value: UserDefaults
    private let suiteName: String

    init() {
        suiteName = "ScrollDirectionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("无法创建隔离的测试 UserDefaults。")
        }
        value = defaults
        value.removePersistentDomain(forName: suiteName)
    }

    deinit {
        value.removePersistentDomain(forName: suiteName)
    }
}
