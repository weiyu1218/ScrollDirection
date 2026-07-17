import Foundation
import Testing
@testable import ScrollDirection

@MainActor
struct AppStateTests {
    private let granted = PermissionStatus(
        accessibilityGranted: true,
        inputMonitoringGranted: true
    )
    private let missingInputMonitoring = PermissionStatus(
        accessibilityGranted: true,
        inputMonitoringGranted: false
    )

    @Test
    func storedEnabledPreferenceStartsAndRegistersLoginItemOnce() {
        let defaults = TemporaryDefaults()
        defaults.value.set(true, forKey: "scrollReversalEnabled")
        let scroll = FakeScrollEventController()
        let permission = FakePermissionController(status: granted)
        let login = FakeLoginItemController(status: .notRegistered)
        let state = makeState(
            scroll: scroll,
            permission: permission,
            login: login,
            defaults: defaults.value
        )

        state.startAtLaunch()
        state.refreshExternalState()

        #expect(state.status == .enabled)
        #expect(scroll.isRunning)
        #expect(login.setEnabledCalls == [true])
        #expect(state.loginItemStatus == .enabled)
    }

    @Test
    func enablingWithMissingPermissionRequestsButDoesNotStart() {
        let defaults = TemporaryDefaults()
        let scroll = FakeScrollEventController()
        let permission = FakePermissionController(
            status: missingInputMonitoring
        )
        let login = FakeLoginItemController(status: .notRegistered)
        let state = makeState(
            scroll: scroll,
            permission: permission,
            login: login,
            defaults: defaults.value
        )

        state.setReversalEnabled(true)

        #expect(permission.requestCallCount == 1)
        #expect(scroll.startCallCount == 0)
        #expect(state.status == .permissionRequired(missingInputMonitoring))
    }

    @Test
    func pausingStopsFilterAndPersistsPreference() {
        let defaults = TemporaryDefaults()
        let scroll = FakeScrollEventController()
        let permission = FakePermissionController(status: granted)
        let login = FakeLoginItemController(status: .enabled)
        let state = makeState(
            scroll: scroll,
            permission: permission,
            login: login,
            defaults: defaults.value
        )

        state.setReversalEnabled(true)
        state.setReversalEnabled(false)

        #expect(state.status == .paused)
        #expect(!scroll.isRunning)
        #expect(scroll.stopCallCount == 1)
        #expect(!defaults.value.bool(forKey: "scrollReversalEnabled"))
    }

    @Test
    func filterCreationFailureIsReportedHonestly() {
        let defaults = TemporaryDefaults()
        defaults.value.set(true, forKey: "scrollReversalEnabled")
        let scroll = FakeScrollEventController()
        scroll.startError = TestFailure(message: "测试过滤器错误")
        let state = makeState(
            scroll: scroll,
            permission: FakePermissionController(status: granted),
            login: FakeLoginItemController(status: .notRegistered),
            defaults: defaults.value
        )

        state.startAtLaunch()

        #expect(state.status == .failed("测试过滤器错误"))
        #expect(!scroll.isRunning)
    }

    @Test
    func loginItemFailureDoesNotDisableScrolling() {
        let defaults = TemporaryDefaults()
        defaults.value.set(true, forKey: "scrollReversalEnabled")
        let login = FakeLoginItemController(status: .notRegistered)
        login.setEnabledError = TestFailure(message: "测试登录项错误")
        let scroll = FakeScrollEventController()
        let state = makeState(
            scroll: scroll,
            permission: FakePermissionController(status: granted),
            login: login,
            defaults: defaults.value
        )

        state.startAtLaunch()

        #expect(state.status == .enabled)
        #expect(scroll.isRunning)
        #expect(state.loginItemError == "测试登录项错误")
    }

    @Test
    func revokedPermissionStopsRunningFilter() {
        let defaults = TemporaryDefaults()
        defaults.value.set(true, forKey: "scrollReversalEnabled")
        let scroll = FakeScrollEventController()
        let permission = FakePermissionController(status: granted)
        let state = makeState(
            scroll: scroll,
            permission: permission,
            login: FakeLoginItemController(status: .enabled),
            defaults: defaults.value
        )
        state.startAtLaunch()

        permission.statusValue = missingInputMonitoring
        state.refreshExternalState()

        #expect(!scroll.isRunning)
        #expect(state.status == .permissionRequired(missingInputMonitoring))
    }

    @Test
    func loginItemApprovalOpensDocumentedSettingsPanel() {
        let defaults = TemporaryDefaults()
        let login = FakeLoginItemController(status: .requiresApproval)
        let state = makeState(
            scroll: FakeScrollEventController(),
            permission: FakePermissionController(status: granted),
            login: login,
            defaults: defaults.value
        )

        state.setLoginItemEnabled(true)

        #expect(login.openSettingsCallCount == 1)
        #expect(login.setEnabledCalls.isEmpty)
    }

    private func makeState(
        scroll: FakeScrollEventController,
        permission: FakePermissionController,
        login: FakeLoginItemController,
        defaults: UserDefaults
    ) -> AppState {
        AppState(
            scrollController: scroll,
            permissionController: permission,
            loginItemController: login,
            defaults: defaults
        )
    }
}
