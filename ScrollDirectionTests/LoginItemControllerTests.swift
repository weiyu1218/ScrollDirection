import ServiceManagement
import Testing
@testable import ScrollDirection

struct LoginItemControllerTests {
    @Test
    func mapsEveryDocumentedMainAppStatus() {
        #expect(
            SystemLoginItemController.map(.notRegistered) == .notRegistered
        )
        #expect(SystemLoginItemController.map(.enabled) == .enabled)
        #expect(
            SystemLoginItemController.map(.requiresApproval)
                == .requiresApproval
        )
        #expect(SystemLoginItemController.map(.notFound) == .notFound)
    }

    @Test
    func onlyEnabledStatusTurnsOnMenuToggle() {
        #expect(LoginItemStatus.enabled.isEnabled)
        #expect(!LoginItemStatus.notRegistered.isEnabled)
        #expect(!LoginItemStatus.requiresApproval.isEnabled)
        #expect(!LoginItemStatus.notFound.isEnabled)
    }

    @Test
    func choosesOperationForEveryDesiredState() throws {
        #expect(
            try SystemLoginItemController.operation(
                enabled: true,
                status: .enabled
            ) == .none
        )
        #expect(
            try SystemLoginItemController.operation(
                enabled: true,
                status: .notRegistered
            ) == .register
        )
        #expect(
            try SystemLoginItemController.operation(
                enabled: true,
                status: .notFound
            ) == .register
        )
        #expect(throws: LoginItemControllerError.self) {
            try SystemLoginItemController.operation(
                enabled: true,
                status: .requiresApproval
            )
        }

        #expect(
            try SystemLoginItemController.operation(
                enabled: false,
                status: .enabled
            ) == .unregister
        )
        #expect(
            try SystemLoginItemController.operation(
                enabled: false,
                status: .requiresApproval
            ) == .unregister
        )
        #expect(
            try SystemLoginItemController.operation(
                enabled: false,
                status: .notRegistered
            ) == .none
        )
        #expect(
            try SystemLoginItemController.operation(
                enabled: false,
                status: .notFound
            ) == .none
        )
    }
}
