import ServiceManagement

enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    var isEnabled: Bool {
        self == .enabled
    }
}

enum LoginItemOperation: Equatable {
    case none
    case register
    case unregister
}

protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

enum LoginItemControllerError: LocalizedError {
    case requiresApproval

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            "登录项需要在系统设置中批准。"
        }
    }
}

struct SystemLoginItemController: LoginItemControlling {
    private var service: SMAppService {
        .mainApp
    }

    var status: LoginItemStatus {
        Self.map(service.status)
    }

    static func map(_ status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .notFound
        }
    }

    static func operation(
        enabled: Bool,
        status: LoginItemStatus
    ) throws -> LoginItemOperation {
        switch (enabled, status) {
        case (true, .enabled),
             (false, .notRegistered),
             (false, .notFound):
            .none
        case (true, .requiresApproval):
            throw LoginItemControllerError.requiresApproval
        case (true, .notRegistered), (true, .notFound):
            .register
        case (false, .enabled), (false, .requiresApproval):
            .unregister
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        switch try Self.operation(enabled: enabled, status: status) {
        case .none:
            return
        case .register:
            try service.register()
        case .unregister:
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
