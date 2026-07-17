import AppKit
import Observation

enum AppStatus: Equatable {
    case enabled
    case paused
    case permissionRequired(PermissionStatus)
    case failed(String)

    var title: String {
        switch self {
        case .enabled:
            "已启用"
        case .paused:
            "已暂停"
        case .permissionRequired(let permissions):
            switch (
                permissions.accessibilityGranted,
                permissions.inputMonitoringGranted
            ) {
            case (false, false):
                "需要辅助功能和输入监控权限"
            case (false, true):
                "需要辅助功能权限"
            case (true, false):
                "需要输入监控权限"
            case (true, true):
                "正在重新检查权限"
            }
        case .failed(let message):
            "失败：\(message)"
        }
    }

    var systemImage: String {
        switch self {
        case .enabled:
            "arrow.up.arrow.down.circle.fill"
        case .paused:
            "pause.circle"
        case .permissionRequired:
            "exclamationmark.triangle"
        case .failed:
            "xmark.octagon"
        }
    }

    var needsPermissionAction: Bool {
        if case .permissionRequired = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor
@Observable
final class AppState {
    private enum DefaultsKey {
        static let reversalEnabled = "scrollReversalEnabled"
        static let didAttemptDefaultLoginItem =
            "didAttemptDefaultLoginItem"
    }

    private let scrollController: ScrollEventControlling
    private let permissionController: PermissionControlling
    private let loginItemController: LoginItemControlling
    private let defaults: UserDefaults

    var isReversalEnabled: Bool
    private(set) var permissions: PermissionStatus
    private(set) var loginItemStatus: LoginItemStatus
    private(set) var status: AppStatus = .paused
    private(set) var loginItemError: String?

    static func live() -> AppState {
        AppState(
            scrollController: ScrollEventController(),
            permissionController: SystemPermissionController(),
            loginItemController: SystemLoginItemController(),
            defaults: .standard
        )
    }

    init(
        scrollController: ScrollEventControlling,
        permissionController: PermissionControlling,
        loginItemController: LoginItemControlling,
        defaults: UserDefaults
    ) {
        self.scrollController = scrollController
        self.permissionController = permissionController
        self.loginItemController = loginItemController
        self.defaults = defaults
        isReversalEnabled = defaults.bool(
            forKey: DefaultsKey.reversalEnabled
        )
        permissions = permissionController.currentStatus()
        loginItemStatus = loginItemController.status
    }

    func startAtLaunch() {
        applyDesiredState(userInitiated: false)
    }

    func setReversalEnabled(_ enabled: Bool) {
        isReversalEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.reversalEnabled)
        applyDesiredState(userInitiated: enabled)
    }

    func refreshExternalState() {
        permissions = permissionController.currentStatus()
        loginItemStatus = loginItemController.status
        applyDesiredState(userInitiated: false)
    }

    func guideToPermissions() {
        permissionController.requestMissingPermissions()
        permissions = permissionController.currentStatus()
        if !permissions.allGranted
            && !permissionController.openSystemSettings() {
            status = .failed("无法打开系统设置。")
            return
        }
        applyDesiredState(userInitiated: false)
    }

    func setLoginItemEnabled(_ enabled: Bool) {
        loginItemError = nil
        if enabled && loginItemStatus == .requiresApproval {
            loginItemController.openSystemSettings()
            return
        }
        do {
            try loginItemController.setEnabled(enabled)
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItemStatus = loginItemController.status
    }

    func retry() {
        applyDesiredState(userInitiated: false)
    }

    func quit() {
        scrollController.stop()
        NSApplication.shared.terminate(nil)
    }

    private func applyDesiredState(userInitiated: Bool) {
        guard isReversalEnabled else {
            scrollController.stop()
            status = .paused
            return
        }

        permissions = permissionController.currentStatus()
        if userInitiated && !permissions.allGranted {
            permissionController.requestMissingPermissions()
            permissions = permissionController.currentStatus()
        }

        guard permissions.allGranted else {
            scrollController.stop()
            status = .permissionRequired(permissions)
            return
        }

        do {
            try scrollController.start()
            guard scrollController.isRunning else {
                status = .failed("滚动事件过滤器没有进入运行状态。")
                return
            }
            status = .enabled
            registerDefaultLoginItemIfNeeded()
        } catch {
            scrollController.stop()
            status = .failed(error.localizedDescription)
        }
    }

    private func registerDefaultLoginItemIfNeeded() {
        guard !defaults.bool(
            forKey: DefaultsKey.didAttemptDefaultLoginItem
        ) else {
            return
        }
        defaults.set(
            true,
            forKey: DefaultsKey.didAttemptDefaultLoginItem
        )
        loginItemError = nil
        do {
            try loginItemController.setEnabled(true)
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItemStatus = loginItemController.status
    }
}
