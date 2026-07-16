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
}
