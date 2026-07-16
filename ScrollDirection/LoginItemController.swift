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

protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

enum LoginItemControllerError: LocalizedError {
    case requiresApproval
    case notFound

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            "登录项需要在系统设置中批准。"
        case .notFound:
            "系统未找到主应用登录项。"
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

    func setEnabled(_ enabled: Bool) throws {
        switch (enabled, status) {
        case (true, .enabled), (false, .notRegistered):
            return
        case (true, .requiresApproval):
            throw LoginItemControllerError.requiresApproval
        case (_, .notFound):
            throw LoginItemControllerError.notFound
        case (true, .notRegistered):
            try service.register()
        case (false, .enabled), (false, .requiresApproval):
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
