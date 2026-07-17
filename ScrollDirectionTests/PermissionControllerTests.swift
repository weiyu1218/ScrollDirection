import Testing
@testable import ScrollDirection

struct PermissionControllerTests {
    @Test
    func allGrantedRequiresBothPermissions() {
        #expect(
            PermissionStatus(
                accessibilityGranted: true,
                inputMonitoringGranted: true
            ).allGranted
        )
        #expect(
            !PermissionStatus(
                accessibilityGranted: false,
                inputMonitoringGranted: true
            ).allGranted
        )
        #expect(
            !PermissionStatus(
                accessibilityGranted: true,
                inputMonitoringGranted: false
            ).allGranted
        )
        #expect(
            !PermissionStatus(
                accessibilityGranted: false,
                inputMonitoringGranted: false
            ).allGranted
        )
    }
}
