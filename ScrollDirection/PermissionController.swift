import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics

struct PermissionStatus: Equatable {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool

    var allGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }
}

protocol PermissionControlling {
    func currentStatus() -> PermissionStatus
    func requestMissingPermissions()
    func openSystemSettings() -> Bool
}

struct SystemPermissionController: PermissionControlling {
    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess()
        )
    }

    func requestMissingPermissions() {
        if !AXIsProcessTrusted() {
            let promptKey =
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions(
                [promptKey: true] as CFDictionary
            )
        }
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    func openSystemSettings() -> Bool {
        guard let settingsURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) else {
            return false
        }
        return NSWorkspace.shared.open(settingsURL)
    }
}
