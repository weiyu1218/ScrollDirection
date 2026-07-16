import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState

    var body: some View {
        Text("状态：\(appState.status.title)")

        Toggle(
            "启用鼠标反向滚动",
            isOn: Binding(
                get: { appState.isReversalEnabled },
                set: { appState.setReversalEnabled($0) }
            )
        )

        Toggle(
            "登录时启动",
            isOn: Binding(
                get: { appState.loginItemStatus.isEnabled },
                set: { appState.setLoginItemEnabled($0) }
            )
        )

        if let loginItemError = appState.loginItemError {
            Text(loginItemError)
        }

        if appState.status.needsPermissionAction {
            Button("请求权限并打开系统设置") {
                appState.guideToPermissions()
            }
        }

        if appState.status.isFailure {
            Button("重新检查") {
                appState.retry()
            }
        }

        Divider()

        Button("退出") {
            appState.quit()
        }
        .keyboardShortcut("q")
        .onAppear {
            appState.refreshExternalState()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            appState.refreshExternalState()
        }
    }
}
