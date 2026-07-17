# ScrollDirection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个仅供用户本人使用的 macOS 菜单栏应用，在系统保持自然滚动开启时，只反转罗技 GPW2 的垂直滚轮，并保持内置触控板的自然滚动和惯性滚动不变。

**Architecture:** 应用保留一个只接收并修改滚动事件的主动 CGEventTap，另用一个 listenOnly 手势 tap 读取双指触摸状态。来源分类器以最近双指手势、NSEvent.phase、momentumPhase 和上一来源判定鼠标或触控板；仅对鼠标事件的三个公开垂直滚动字段取反。AppState 统一协调权限、事件过滤器、登录项与菜单状态，所有系统适配器都通过小型协议注入，以便纯逻辑测试不修改真实系统状态。

**Tech Stack:** Xcode 26.6、Swift 6、SwiftUI MenuBarExtra、Observation、Core Graphics、ApplicationServices、ServiceManagement、Swift Testing、macOS 26。

## Global Constraints

- 产品名固定为 ScrollDirection，bundle identifier 固定为 com.weiyu1218.ScrollDirection。
- 开发目标固定为 macOS 26.0；实际验收机器为 Apple Silicon、macOS 26.3 Build 25D125。
- 使用 Xcode 26.6、macOS SDK 26.5、Swift 6 严格并发检查、Personal Team 和自动签名。
- App Sandbox 必须关闭；不使用驱动、内核扩展、守护进程、第三方依赖、私有 API 或未公开的系统设置深链。
- 应用只显示菜单栏图标，不显示 Dock 图标，不创建普通窗口。
- 系统“自然滚动”保持开启；应用不得读取或修改该系统设置。
- 只反转 scrollWheelEventDeltaAxis1、scrollWheelEventFixedPtDeltaAxis1 和 scrollWheelEventPointDeltaAxis1；水平字段与其他事件字段不得写入。
- 只能有一个能够修改事件的主动 CGEventTap，且其事件掩码只包含 scrollWheel；手势 tap 必须使用 listenOnly，不能修改或阻止事件。
- scrollWheelEventIsContinuous 只记录为诊断数据，不得再决定来源。
- 辅助功能和输入监控权限同时通过后才允许创建主动事件过滤器。
- 权限请求只由用户主动点击触发；启动恢复和状态刷新不得循环弹出授权框。
- 第一次成功启动事件过滤器后只尝试一次默认注册登录项；登录项失败不得停止滚动功能。
- 已实测 GPW2 与内置触控板的 continuousValue 均为 0，原分类路线已停止。修订路线必须实测 GPW2 为 mouse、双指滚动和惯性滚动为 trackpad 后才能继续发布验收。
- 不预设性能数字；CPU、内存和真实设备结果只能记录实际测量值。
- 开发分支固定为 feature/scroll-direction-app；每次提交前必须审查差异并通过相关测试。
- 提交信息采用中文“类型: 描述”格式，不 force push，不修改任何已经推送的历史。
- GitHub 目标固定为公开仓库 weiyu1218/ScrollDirection，提交作者固定为 weiyu1218 与 GitHub noreply 地址。
- 本计划不创建 README；功能更新总结得到用户确认后，才能另行创建或更新 README。

---

## File Structure

- Create: .gitignore
  - 排除 Xcode 用户状态、DerivedData 和 .DS_Store，防止个人界面状态进入公开仓库。
- Create: ScrollDirection.xcodeproj/project.pbxproj
  - Xcode 生成的应用与测试目标、自动签名、部署目标和 Info.plist 构建设置。
- Modify: ScrollDirection/ScrollDirectionApp.swift
  - 应用入口，只创建 MenuBarExtra，并在启动时恢复期望状态。
- Delete: ScrollDirection/ContentView.swift
  - 删除 macOS App 模板的普通窗口内容。
- Create: ScrollDirection/ScrollSource.swift
  - 保存最近双指手势时间和上一来源，以手势与滚动阶段判定 mouse 或 trackpad。
- Create: ScrollDirection/VerticalScrollDelta.swift
  - 读取、反转并写回三个垂直滚动字段。
- Create: ScrollDirection/ScrollEventController.swift
  - 创建、恢复和销毁唯一的主动滚动 tap 与只读手势 tap。
- Create: ScrollDirection/PermissionController.swift
  - 检查和请求辅助功能与输入监控权限，并通过公开 NSWorkspace API 打开系统设置应用。
- Create: ScrollDirection/LoginItemController.swift
  - 映射 SMAppService 状态并注册或取消主应用登录项。
- Create: ScrollDirection/AppState.swift
  - 持久化用户期望，协调系统适配器并生成真实菜单状态。
- Create: ScrollDirection/MenuBarView.swift
  - 菜单状态、功能开关、登录开关、权限入口、重试和退出。
- Create: ScrollDirectionTests/ScrollSourceTests.swift
  - 双指手势、滚动阶段、惯性阶段和鼠标回退的来源分类测试。
- Create: ScrollDirectionTests/VerticalScrollDeltaTests.swift
  - 三类垂直值反转测试。
- Create: ScrollDirectionTests/ScrollEventControllerTests.swift
  - CGEvent 字段变换、触控板原样放行和水平字段不变测试。
- Create: ScrollDirectionTests/PermissionControllerTests.swift
  - 权限组合判定测试。
- Create: ScrollDirectionTests/LoginItemControllerTests.swift
  - SMAppService 状态映射测试。
- Create: ScrollDirectionTests/TestDoubles.swift
  - AppState 使用的无系统副作用测试替身。
- Create: ScrollDirectionTests/AppStateTests.swift
  - 启用、暂停、权限、失败、登录项默认行为和权限撤销测试。

### Task 1: 创建 Xcode 工程并以测试驱动实现来源分类

**Files:**
- Create: .gitignore
- Create: ScrollDirection.xcodeproj/project.pbxproj
- Create: ScrollDirection/ScrollDirectionApp.swift
- Create: ScrollDirection/ContentView.swift
- Create: ScrollDirectionTests/ScrollSourceTests.swift
- Create: ScrollDirection/ScrollSource.swift

**Interfaces:**
- Consumes: Xcode 26.6 中的 macOS App 和 Unit Testing Bundle 模板。
- Produces: ScrollSource.classify(continuousValue: Int64) -> ScrollSource。

- [ ] **Step 1: 用 Xcode 26.6 创建工程**

使用 Computer Use 打开 Xcode，依次选择 Create New Project、macOS、App，填写：

~~~text
Product Name: ScrollDirection
Team: 已配置的 Personal Team
Organization Identifier: com.weiyu1218
Bundle Identifier: com.weiyu1218.ScrollDirection
Interface: SwiftUI
Language: Swift
Testing System: None
Storage: None
~~~

保存到仓库根目录 /Users/fwy/Documents/Codex/2026-07-16/da，不勾选创建新的 Git 仓库。随后通过 File、New、Target 添加 macOS Unit Testing Bundle，名称为 ScrollDirectionTests；如果目标表单提供 Testing System，选择 Swift Testing。

- [ ] **Step 2: 配置目标**

在 ScrollDirection 应用目标中设置：

~~~text
Deployment Target: macOS 26.0
Automatically manage signing: On
Team: 已配置的 Personal Team
Application is agent (UIElement): YES
Enable App Sandbox (ENABLE_APP_SANDBOX): No
Swift Language Version (SWIFT_VERSION): Swift 6
Strict Concurrency Checking (SWIFT_STRICT_CONCURRENCY): Complete
~~~

检查工程构建设置：

~~~bash
xcodebuild -project ScrollDirection.xcodeproj -scheme ScrollDirection -showBuildSettings | rg 'MACOSX_DEPLOYMENT_TARGET|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_STYLE|DEVELOPMENT_TEAM|INFOPLIST_KEY_LSUIElement|ENABLE_APP_SANDBOX|SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY'
~~~

Expected: deployment target 为 26.0，bundle identifier 为 com.weiyu1218.ScrollDirection，签名模式为 Automatic，LSUIElement 为 YES，ENABLE_APP_SANDBOX 为 NO，Swift 语言版本为 6，严格并发检查为 complete。

- [ ] **Step 3: 创建公开仓库所需的忽略规则**

创建 .gitignore：

~~~gitignore
.DS_Store
DerivedData/
*.xcuserstate
xcuserdata/
~~~

- [ ] **Step 4: 先写来源分类失败测试**

创建 ScrollDirectionTests/ScrollSourceTests.swift：

~~~swift
import Testing
@testable import ScrollDirection

struct ScrollSourceTests {
    @Test
    func zeroContinuousValueIsMouse() {
        #expect(ScrollSource.classify(continuousValue: 0) == .mouse)
    }

    @Test
    func nonzeroContinuousValueIsTrackpad() {
        #expect(ScrollSource.classify(continuousValue: 1) == .trackpad)
        #expect(ScrollSource.classify(continuousValue: -1) == .trackpad)
    }
}
~~~

- [ ] **Step 5: 运行测试并确认按预期失败**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST FAILED，编译器报告找不到 ScrollSource。

- [ ] **Step 6: 实现最小分类逻辑**

创建 ScrollDirection/ScrollSource.swift：

~~~swift
enum ScrollSource: Equatable {
    case mouse
    case trackpad

    static func classify(continuousValue: Int64) -> ScrollSource {
        continuousValue == 0 ? .mouse : .trackpad
    }
}
~~~

- [ ] **Step 7: 运行测试并确认通过**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST SUCCEEDED，2 个来源分类测试通过。

- [ ] **Step 8: 审查并提交**

Run:

~~~bash
git status --short
git diff --check
git add .gitignore ScrollDirection.xcodeproj ScrollDirection ScrollDirectionTests
git diff --cached --check
git diff --cached
git commit -m "chore: 创建macOS应用工程"
~~~

Expected: 暂存差异不包含 xcuserdata、DerivedData、私有邮箱或 App Sandbox entitlement，审查完成后提交成功。

### Task 2: 测试驱动实现垂直滚动数值模型

**Files:**
- Create: ScrollDirectionTests/VerticalScrollDeltaTests.swift
- Create: ScrollDirection/VerticalScrollDelta.swift

**Interfaces:**
- Consumes: CGEvent 的三个 Axis1 字段。
- Produces: VerticalScrollDelta.init(event:), VerticalScrollDelta.inverted 和 write(to:)。

- [ ] **Step 1: 写数值反转失败测试**

创建 ScrollDirectionTests/VerticalScrollDeltaTests.swift：

~~~swift
import Testing
@testable import ScrollDirection

struct VerticalScrollDeltaTests {
    @Test
    func inversionChangesAllVerticalRepresentations() {
        let delta = VerticalScrollDelta(line: 3, fixedPoint: 3.5, point: 30)

        #expect(
            delta.inverted
                == VerticalScrollDelta(line: -3, fixedPoint: -3.5, point: -30)
        )
    }

    @Test
    func inversionPreservesZero() {
        let delta = VerticalScrollDelta(line: 0, fixedPoint: 0, point: 0)

        #expect(
            delta.inverted
                == VerticalScrollDelta(line: 0, fixedPoint: 0, point: 0)
        )
    }
}
~~~

- [ ] **Step 2: 运行测试并确认按预期失败**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST FAILED，编译器报告找不到 VerticalScrollDelta。

- [ ] **Step 3: 实现垂直字段读取、反转和写回**

创建 ScrollDirection/VerticalScrollDelta.swift：

~~~swift
import CoreGraphics

struct VerticalScrollDelta: Equatable {
    let line: Int64
    let fixedPoint: Double
    let point: Int64

    init(line: Int64, fixedPoint: Double, point: Int64) {
        self.line = line
        self.fixedPoint = fixedPoint
        self.point = point
    }

    init(event: CGEvent) {
        line = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        fixedPoint = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        point = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    }

    var inverted: VerticalScrollDelta {
        VerticalScrollDelta(
            line: -line,
            fixedPoint: -fixedPoint,
            point: -point
        )
    }

    func write(to event: CGEvent) {
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: line)
        event.setDoubleValueField(
            .scrollWheelEventFixedPtDeltaAxis1,
            value: fixedPoint
        )
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: point)
    }
}
~~~

- [ ] **Step 4: 运行测试并确认通过**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST SUCCEEDED，来源分类与垂直值测试全部通过。

- [ ] **Step 5: 审查并提交**

Run:

~~~bash
git diff --check
git add ScrollDirection/VerticalScrollDelta.swift ScrollDirectionTests/VerticalScrollDeltaTests.swift
git diff --cached --check
git diff --cached
git commit -m "feat: 添加垂直滚动数值变换"
~~~

Expected: 只出现三个 Axis1 字段，没有 Axis2 或 Axis3 写入。

### Task 3: 测试驱动实现滚动事件过滤器

**Files:**
- Create: ScrollDirectionTests/ScrollEventControllerTests.swift
- Create: ScrollDirection/ScrollEventController.swift

**Interfaces:**
- Consumes: ScrollSource.classify(continuousValue:) 与 VerticalScrollDelta。
- Produces: ScrollEventControlling、ScrollEventController.start()、stop()、isRunning 和 transformScrollEvent(_:)。

- [ ] **Step 1: 写 CGEvent 变换失败测试**

创建 ScrollDirectionTests/ScrollEventControllerTests.swift：

~~~swift
import CoreGraphics
import Testing
@testable import ScrollDirection

struct ScrollEventControllerTests {
    @Test
    func mouseEventInvertsVerticalFieldsAndPreservesHorizontalFields() throws {
        let event = try makeEvent(continuousValue: 0)

        ScrollEventController.transformScrollEvent(event)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -3.5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -30)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 4)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) == 4.5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 40)
    }

    @Test
    func trackpadEventIsUnchanged() throws {
        let event = try makeEvent(continuousValue: 1)
        let verticalBefore = VerticalScrollDelta(event: event)
        let horizontalLineBefore = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let horizontalFixedBefore = event.getDoubleValueField(
            .scrollWheelEventFixedPtDeltaAxis2
        )
        let horizontalPointBefore = event.getIntegerValueField(
            .scrollWheelEventPointDeltaAxis2
        )

        ScrollEventController.transformScrollEvent(event)

        #expect(VerticalScrollDelta(event: event) == verticalBefore)
        #expect(
            event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
                == horizontalLineBefore
        )
        #expect(
            event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
                == horizontalFixedBefore
        )
        #expect(
            event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
                == horizontalPointBefore
        )
    }

    private func makeEvent(continuousValue: Int64) throws -> CGEvent {
        let event = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 2,
                wheel1: 3,
                wheel2: 4,
                wheel3: 0
            )
        )
        event.setIntegerValueField(
            .scrollWheelEventIsContinuous,
            value: continuousValue
        )
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 3)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 3.5)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 30)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 4)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 4.5)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 40)
        return event
    }
}
~~~

- [ ] **Step 2: 运行测试并确认按预期失败**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST FAILED，编译器报告找不到 ScrollEventController。

- [ ] **Step 3: 实现单一主动事件过滤器**

创建 ScrollDirection/ScrollEventController.swift：

~~~swift
import CoreGraphics
import Foundation

protocol ScrollEventControlling: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop()
}

enum ScrollEventControllerError: LocalizedError {
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var errorDescription: String? {
        switch self {
        case .eventTapCreationFailed:
            "无法创建滚动事件过滤器。"
        case .runLoopSourceCreationFailed:
            "无法连接滚动事件过滤器与主运行循环。"
        }
    }
}

final class ScrollEventController: ScrollEventControlling {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() throws {
        precondition(Thread.isMainThread)
        if isRunning { return }
        stop()

        let eventMask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let controller = Unmanaged<ScrollEventController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout
                || type == .tapDisabledByUserInput {
                if let eventTap = controller.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .scrollWheel else {
                return Unmanaged.passUnretained(event)
            }
            Self.transformScrollEvent(event)
            return Unmanaged.passUnretained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw ScrollEventControllerError.eventTapCreationFailed
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            throw ScrollEventControllerError.runLoopSourceCreationFailed
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        precondition(Thread.isMainThread)
        tearDown()
    }

    static func transformScrollEvent(_ event: CGEvent) {
        let continuousValue = event.getIntegerValueField(
            .scrollWheelEventIsContinuous
        )
        guard ScrollSource.classify(continuousValue: continuousValue) == .mouse
        else {
            return
        }
        VerticalScrollDelta(event: event).inverted.write(to: event)
    }

    private func tearDown() {
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    deinit {
        tearDown()
    }
}
~~~

- [ ] **Step 4: 运行测试并确认通过**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST SUCCEEDED，鼠标三个垂直字段取反，触控板与水平字段保持原值。

- [ ] **Step 5: 静态检查事件范围**

Run:

~~~bash
rg -n 'mouseMoved|keyDown|Axis2|Axis3|CGEventPost' ScrollDirection/ScrollEventController.swift ScrollDirection/VerticalScrollDelta.swift
~~~

Expected: 无匹配；应用源码没有监听鼠标移动或键盘，没有写入水平字段，也没有重新发布事件。

- [ ] **Step 6: 审查并提交**

Run:

~~~bash
git diff --check
git add ScrollDirection/ScrollEventController.swift ScrollDirectionTests/ScrollEventControllerTests.swift
git diff --cached --check
git diff --cached
git commit -m "feat: 添加滚动事件过滤器"
~~~

Expected: 回调只读取连续标记、变换三个垂直字段和处理过滤器恢复。

### Task 4: 实现权限适配器

**Files:**
- Create: ScrollDirectionTests/PermissionControllerTests.swift
- Create: ScrollDirection/PermissionController.swift

**Interfaces:**
- Consumes: AXIsProcessTrusted、AXIsProcessTrustedWithOptions、CGPreflightListenEventAccess、CGRequestListenEventAccess 和 NSWorkspace。
- Produces: PermissionStatus 与 PermissionControlling。

- [ ] **Step 1: 写权限组合失败测试**

创建 ScrollDirectionTests/PermissionControllerTests.swift：

~~~swift
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
~~~

- [ ] **Step 2: 运行测试并确认按预期失败**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST FAILED，编译器报告找不到 PermissionStatus。

- [ ] **Step 3: 实现公开权限 API 适配器**

创建 ScrollDirection/PermissionController.swift：

~~~swift
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
~~~

这里不使用 x-apple.systempreferences 深链。菜单操作先调用系统公开的授权请求，再用公开 NSWorkspace API 打开系统设置应用；具体 Privacy & Security 页面由系统授权提示引导。

- [ ] **Step 4: 运行测试与 Swift 6 并发检查**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests SWIFT_STRICT_CONCURRENCY=complete
~~~

Expected: TEST SUCCEEDED，且 kAXTrustedCheckOptionPrompt 不产生 Swift 6 并发错误。

- [ ] **Step 5: 审查并提交**

Run:

~~~bash
git diff --check
git add ScrollDirection/PermissionController.swift ScrollDirectionTests/PermissionControllerTests.swift
git diff --cached --check
git diff --cached
git commit -m "feat: 添加系统权限检查与引导"
~~~

Expected: 权限适配器不创建轮询、不修改 TCC 数据库、不使用未公开设置链接。

### Task 5: 实现登录项适配器

**Files:**
- Create: ScrollDirectionTests/LoginItemControllerTests.swift
- Create: ScrollDirection/LoginItemController.swift

**Interfaces:**
- Consumes: SMAppService.mainApp.status、register()、unregister() 和 openSystemSettingsLoginItems()。
- Produces: LoginItemStatus 与 LoginItemControlling。

- [ ] **Step 1: 写登录项状态映射失败测试**

创建 ScrollDirectionTests/LoginItemControllerTests.swift：

~~~swift
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
~~~

- [ ] **Step 2: 运行测试并确认按预期失败**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST FAILED，编译器报告找不到登录项类型。

- [ ] **Step 3: 实现 SMAppService 适配器**

创建 ScrollDirection/LoginItemController.swift：

~~~swift
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
~~~

- [ ] **Step 4: 运行测试并确认通过**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST SUCCEEDED，四种公开状态均有明确映射。

- [ ] **Step 5: 审查并提交**

Run:

~~~bash
git diff --check
git add ScrollDirection/LoginItemController.swift ScrollDirectionTests/LoginItemControllerTests.swift
git diff --cached --check
git diff --cached
git commit -m "feat: 添加登录时启动管理"
~~~

Expected: 单元测试不调用真实 register 或 unregister，系统状态不被测试修改。

### Task 6: 测试驱动实现 AppState 协调逻辑

**Files:**
- Create: ScrollDirectionTests/TestDoubles.swift
- Create: ScrollDirectionTests/AppStateTests.swift
- Create: ScrollDirection/AppState.swift

**Interfaces:**
- Consumes: ScrollEventControlling、PermissionControlling、LoginItemControlling 和 UserDefaults。
- Produces: AppStatus 与 AppState 的启动、开关、权限、登录项、重试和退出操作。

- [ ] **Step 1: 创建无系统副作用的测试替身**

创建 ScrollDirectionTests/TestDoubles.swift：

~~~swift
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
~~~

- [ ] **Step 2: 写 AppState 失败测试**

创建 ScrollDirectionTests/AppStateTests.swift：

~~~swift
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
~~~

- [ ] **Step 3: 运行测试并确认按预期失败**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST FAILED，编译器报告找不到 AppState 与 AppStatus。

- [ ] **Step 4: 实现 AppState**

创建 ScrollDirection/AppState.swift：

~~~swift
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
~~~

- [ ] **Step 5: 运行 AppState 测试并确认通过**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' -only-testing:ScrollDirectionTests
~~~

Expected: TEST SUCCEEDED；权限缺失不启动过滤器，暂停释放过滤器，失败真实显示，登录项默认只尝试一次，登录项失败不影响滚动。

- [ ] **Step 6: 审查并提交**

Run:

~~~bash
git diff --check
git add ScrollDirection/AppState.swift ScrollDirectionTests/TestDoubles.swift ScrollDirectionTests/AppStateTests.swift
git diff --cached --check
git diff --cached
git commit -m "feat: 添加应用状态协调"
~~~

Expected: AppState 是界面状态单一来源，测试替身不调用任何真实系统权限或登录项 API。

### Task 7: 构建菜单栏界面并移除普通窗口

**Files:**
- Create: ScrollDirection/MenuBarView.swift
- Modify: ScrollDirection/ScrollDirectionApp.swift
- Delete: ScrollDirection/ContentView.swift

**Interfaces:**
- Consumes: AppState 的公开属性和操作。
- Produces: 无 Dock 图标、无普通窗口的 MenuBarExtra 应用。

- [ ] **Step 1: 创建菜单内容**

创建 ScrollDirection/MenuBarView.swift：

~~~swift
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
~~~

- [ ] **Step 2: 替换应用入口**

将 ScrollDirection/ScrollDirectionApp.swift 完整替换为：

~~~swift
import SwiftUI

@main
@MainActor
struct ScrollDirectionApp: App {
    @State private var appState: AppState

    init() {
        let appState = AppState.live()
        appState.startAtLaunch()
        _appState = State(initialValue: appState)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.status.systemImage)
                .accessibilityLabel("ScrollDirection")
        }
        .menuBarExtraStyle(.menu)
    }
}
~~~

- [ ] **Step 3: 删除模板普通窗口视图**

使用 apply_patch 删除 ScrollDirection/ContentView.swift。确认工程采用 Xcode 26 文件系统同步组后，不手工编辑 project.pbxproj 的文件引用。

- [ ] **Step 4: 运行完整测试和 Debug 构建**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' SWIFT_STRICT_CONCURRENCY=complete
xcodebuild build -project ScrollDirection.xcodeproj -scheme ScrollDirection -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ScrollDirectionDerivedData
~~~

Expected: TEST SUCCEEDED 与 BUILD SUCCEEDED。

- [ ] **Step 5: 验证生成的应用属性**

Run:

~~~bash
plutil -p /tmp/ScrollDirectionDerivedData/Build/Products/Debug/ScrollDirection.app/Contents/Info.plist | rg 'CFBundleIdentifier|LSUIElement'
codesign --verify --deep --strict --verbose=2 /tmp/ScrollDirectionDerivedData/Build/Products/Debug/ScrollDirection.app
codesign -d --entitlements :- /tmp/ScrollDirectionDerivedData/Build/Products/Debug/ScrollDirection.app
~~~

Expected: bundle identifier 为 com.weiyu1218.ScrollDirection，LSUIElement 为 true，代码签名验证成功，entitlements 中没有 com.apple.security.app-sandbox。

- [ ] **Step 6: 审查并提交**

Run:

~~~bash
git diff --check
git add ScrollDirection/ScrollDirectionApp.swift ScrollDirection/MenuBarView.swift ScrollDirection/ContentView.swift ScrollDirection.xcodeproj
git diff --cached --check
git diff --cached
git commit -m "feat: 添加菜单栏交互界面"
~~~

Expected: 没有 WindowGroup、普通设置窗口或 Dock 界面，删除记录仅限模板 ContentView.swift。

### Task 8: 安装 Debug 应用并执行真实设备分类门槛

**Files:**
- No repository file changes.
- Install: /Applications/ScrollDirection.app

**Interfaces:**
- Consumes: 已签名 Debug 应用、GPW2 LIGHTSPEED 鼠标和 Mac 内置触控板。
- Produces: 两类真实硬件的 continuousValue 验证结论和硬性分支结果。

- [ ] **Step 1: 检查安装目标**

Run:

~~~bash
test ! -e /Applications/ScrollDirection.app
~~~

Expected: 首次安装时退出码为 0。若路径已存在，先读取其 CFBundleIdentifier 和签名；不是本项目生成物时停止并请求用户决定，不覆盖。

- [ ] **Step 2: 安装并启动固定路径应用**

Run:

~~~bash
ditto /tmp/ScrollDirectionDerivedData/Build/Products/Debug/ScrollDirection.app /Applications/ScrollDirection.app
codesign --verify --deep --strict --verbose=2 /Applications/ScrollDirection.app
open /Applications/ScrollDirection.app
~~~

Expected: 菜单栏出现 ScrollDirection 图标，Dock 中没有应用图标，菜单状态为已暂停或需要权限。

- [ ] **Step 3: 在权限修改前进行操作时确认**

暂停执行并向用户说明：下一步将触发辅助功能和输入监控授权提示，并需要在系统设置的 Privacy & Security 中为 /Applications/ScrollDirection.app 开启两项权限。得到当下确认后，才通过 Computer Use 操作系统安全设置；若用户选择自行操作，则等待用户完成。

- [ ] **Step 4: 启用功能并核对两项权限**

点击“启用鼠标反向滚动”，再点击“请求权限并打开系统设置”。授权后重新打开菜单。

Expected: 菜单状态变为“已启用”；若系统要求重启应用，先退出再打开，不能把“需要权限”报告为成功。

- [ ] **Step 5: 用 Xcode 附加到固定路径进程并设置断点**

在 Xcode 使用 Debug、Attach to Process，选择正在运行的 ScrollDirection。运行：

~~~bash
rg -n 'let continuousValue' ScrollDirection/ScrollEventController.swift
~~~

在读取 continuousValue 后的 guard 行设置断点。Debug 构建中执行：

~~~lldb
p continuousValue
~~~

- [ ] **Step 6: 验证 GPW2**

暂停并请用户只使用 GPW2 滚轮滚动一格。断点命中后读取 continuousValue。

Expected: continuousValue 精确等于 0。记录真实值后继续执行。

Actual: GPW2 实测为 0，通过该半项门槛。

- [ ] **Step 7: 验证触控板**

请用户只使用内置触控板双指滚动。断点命中后读取 continuousValue。

Expected: continuousValue 不等于 0。记录真实值后移除断点并从进程分离。

Actual: 内置触控板连续两条事件均为 0；两条事件的 scrollPhase 和 momentumPhase 也均为 0。该半项门槛失败。

- [ ] **Step 8: 执行硬性分支判断**

两项都满足时继续 Task 9。任一不满足时立即暂停应用、保留原始观测值、停止后续发布，并向用户提交基于手势状态的重新设计方案；不得修改分类常量来伪造通过。

Actual: 已从调试进程分离，将持久启用值恢复为 false，重新启动固定路径应用并停止 Task 9。

### Task 8A: 以双指手势状态重新实现来源分类

**Approval gate:** 本任务属于分类架构修改。只有用户确认本修订方案后才能修改以下应用代码。

**Files:**
- Modify: ScrollDirection/ScrollSource.swift
- Modify: ScrollDirection/ScrollEventController.swift
- Modify: ScrollDirectionTests/ScrollSourceTests.swift
- Modify: ScrollDirectionTests/ScrollEventControllerTests.swift

**Interfaces:**
- Consumes: listenOnly 手势事件中的触摸点、滚动事件的 NSEvent.phase、momentumPhase、事件时间戳和上一来源。
- Produces: ScrollSourceClassifier.recordGesture(touchingCount:gesturePhase:timestamp:) 和 ScrollSourceClassifier.classifyScroll(timestamp:phase:momentumPhase:)。

- [ ] **Step 1: 先写新的来源分类失败测试**

删除以 continuousValue 为唯一输入的断言，新增以下纯逻辑用例：

~~~text
没有双指手势、phase 和 momentumPhase -> mouse
最近 222 ms 内记录到两个及以上触摸点 -> trackpad
只有零个或一个触摸点 -> mouse
手势 ended 或 cancelled -> 立即清除活动的双指证据
phase 表示流体滚动 -> trackpad
上一来源为 trackpad 且 momentumPhase 非空 -> trackpad
上一来源为 mouse 且 momentumPhase 非空 -> mouse
超过双指关联窗口且没有滚动阶段证据 -> mouse
~~~

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS' -derivedDataPath /tmp/ScrollDirectionDerivedData -jobs 1 -only-testing:ScrollDirectionTests/ScrollSourceTests
~~~

Expected: 新测试因 ScrollSourceClassifier 尚不存在而失败。

- [ ] **Step 2: 实现最小来源状态机**

在 ScrollSource.swift 中就地替换原 continuousValue 分类函数：

~~~text
记录最近一次两个及以上触摸点的事件时间戳
记录双指手势是否仍处于活动状态
手势 ended 或 cancelled 时立即清除活动状态和关联窗口
以 222 ms 作为手势与随后滚动事件的关联窗口
phase 非空时判定为触控板滚动
momentumPhase 非空且上一来源为 trackpad 时继续判定为 trackpad
没有上述证据时判定为 mouse
每次分类后更新上一来源
~~~

所有时间比较使用 CGEvent.timestamp 的单调纳秒值；测试直接注入时间戳，不读取系统时钟。

Expected: Step 1 的全部分类测试通过。

- [ ] **Step 3: 先写事件控制器失败测试**

将事件数值变换与来源判定解耦，新增以下测试：

~~~text
明确传入 mouse -> 只反转三个垂直字段
明确传入 trackpad -> 所有字段原样保留
手势回调少于两个触摸点 -> 不建立触控板证据
手势回调两个及以上触摸点 -> 建立触控板证据
stop -> 主动与只读两个 tap 的资源都被释放
~~~

Expected: 测试先因控制器尚未接收手势状态而失败。

- [ ] **Step 4: 增加只读手势 tap**

在 ScrollEventController.swift 中：

~~~text
先创建 listenOnly 手势 tap，事件掩码只包含 NSEvent.EventTypeMask.gesture
将手势 CGEvent 转为 NSEvent
读取 touches(matching: .touching, in: nil).count
把触摸点数量、手势 phase 和事件时间戳交给来源分类器
保留现有唯一主动滚动 tap，事件掩码仍只包含 scrollWheel
滚动回调读取 NSEvent.phase 和 momentumPhase 后查询来源分类器
只有来源为 mouse 时调用 VerticalScrollDelta.inverted.write
~~~

若任一 tap 创建或 RunLoop source 创建失败，完整释放两个 tap 的已有资源并返回真实错误。回调不记录日志、不访问网络、不刷新界面。

- [ ] **Step 5: 运行完整测试和 Debug 构建**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS' -derivedDataPath /tmp/ScrollDirectionDerivedData -jobs 1
xcodebuild build -project ScrollDirection.xcodeproj -scheme ScrollDirection -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/ScrollDirectionDerivedData -jobs 1
~~~

Expected: 全部测试和构建成功；Swift 6 严格并发检查没有新增警告。

- [ ] **Step 6: 审查并提交修订**

Run:

~~~bash
git diff --check
git diff -- ScrollDirection/ScrollSource.swift ScrollDirection/ScrollEventController.swift ScrollDirectionTests/ScrollSourceTests.swift ScrollDirectionTests/ScrollEventControllerTests.swift
git add ScrollDirection/ScrollSource.swift ScrollDirection/ScrollEventController.swift ScrollDirectionTests/ScrollSourceTests.swift ScrollDirectionTests/ScrollEventControllerTests.swift
git diff --cached --check
git diff --cached
git commit -m "fix: 使用双指手势识别触控板滚动"
~~~

Expected: 代码审查确认只有一个主动滚动 tap；另一个 tap 为 listenOnly；没有私有 API、IOHID 枚举或未要求的设置。

- [ ] **Step 7: 重新安装并执行修订硬件门槛**

用新 Debug 构建替换 /Applications/ScrollDirection.app，保持 bundle identifier 和签名不变。权限仍须读取系统真实状态，不能假设已保留。通过断点依次验证：

~~~text
GPW2 单格滚轮 -> touchingCount 小于 2，最终来源为 mouse
触控板双指首条滚动 -> touchingCount 至少为 2，最终来源为 trackpad
触控板手指离开后的惯性滚动 -> 最终来源持续为 trackpad
触控板结束后立即使用 GPW2 -> 下一条 GPW2 事件恢复为 mouse
~~~

Expected: 四项全部通过后才能进入 Task 9。任一不通过时再次停止，不用数值大小、连续标记或硬编码设备名称伪造来源。

### Task 9: 真实功能、恢复、登录和性能验收

**Files:**
- No repository file changes unless a verified defect requires returning to the corresponding task.

**Interfaces:**
- Consumes: 已通过真实设备分类门槛的 /Applications/ScrollDirection.app。
- Produces: 功能、生命周期和性能的实际验收结果。

- [ ] **Step 1: 验证标准应用中的方向**

保持系统自然滚动开启，在 Finder、Safari、终端、系统设置和一个标准长文档界面分别执行：

~~~text
GPW2 向上滚轮 -> 内容按传统鼠标方向移动
触控板双指向上 -> 内容按 macOS 自然滚动方向移动
快速交替两种设备 -> 每个事件立即采用对应方向
触控板手指离开后的惯性滚动 -> 方向与轨迹连续
~~~

Expected: 五类界面全部满足，水平行为未被应用改变。

- [ ] **Step 2: 验证暂停和退出**

关闭“启用鼠标反向滚动”，测试 GPW2 与触控板；重新启用后再次测试。然后选择“退出”并测试。

Expected: 暂停或退出后系统原始滚动立即恢复；重新启用后只反转 GPW2。

- [ ] **Step 3: 验证接收器与睡眠恢复**

依次断开和重连 LIGHTSPEED 接收器、锁屏解锁、睡眠唤醒，每次返回后测试两类设备。

Expected: 菜单状态真实，事件过滤器继续工作；若被系统禁用，回调恢复后 isRunning 为 true。

- [ ] **Step 4: 验证登录启动**

确认菜单“登录时启动”显示为开启，且系统设置 Login Items 中状态为 enabled。在用户同意中断当前登录会话后执行重新登录。

Expected: ScrollDirection 自动出现在菜单栏，恢复用户的启用选择，不主动重复弹出已经授予的权限框。

- [ ] **Step 5: 验证权限撤销**

在修改系统安全设置前再次取得当下确认。撤销输入监控或辅助功能中的一项，重新激活应用并打开菜单。

Expected: 过滤器停止，菜单显示缺少的具体权限，不显示“已启用”。完成测试后在用户确认下恢复权限。

- [ ] **Step 6: 测量实际 CPU 与内存**

获取进程并分别在空闲、持续 GPW2 滚动、持续触控板滚动三种阶段运行：

~~~bash
PID="$(pgrep -x ScrollDirection)"
top -l 5 -s 1 -pid "$PID" -stats pid,cpu,mem,threads
~~~

Expected: 每个阶段保留 top 的实际五次采样；不在计划中设置虚构阈值。若出现持续高 CPU、内存增长或过滤器超时，使用 systematic-debugging 流程定位并修复后重新执行全部相关验收。

### Task 10: 最终清理、发布构建和代码审查

**Files:**
- Modify only files tied to a verified defect.
- Replace installed app: /Applications/ScrollDirection.app

**Interfaces:**
- Consumes: 所有自动测试和真实设备验收结果。
- Produces: 清洁、签名有效、固定路径安装的 Release 应用与可公开提交历史。

- [ ] **Step 1: 扫描调试痕迹和未授权功能**

Run:

~~~bash
rg -n 'TO''DO|FIX''ME|print\(|debugPrint\(|Logger|os_log|IOHID|CGEventPost|Axis2|Axis3' ScrollDirection
rg -n '\bWindowGroup\b|\bSettings[[:space:]]*\{|\bDocumentGroup\b' ScrollDirection
~~~

Expected: 两条命令均无匹配。Axis2 只允许存在于测试文件中，用于证明水平字段未变化。

- [ ] **Step 2: 执行完整代码审查**

Run:

~~~bash
git status --short
git diff --check
git log --oneline --decorate --graph main..feature/scroll-direction-app
~~~

逐文件审查调用链：MenuBarView -> AppState -> PermissionController、ScrollEventController、LoginItemController；确认错误只向上转换为真实状态，事件回调无 I/O、日志、等待或界面更新。

- [ ] **Step 3: 运行最终自动验证**

Run:

~~~bash
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' SWIFT_STRICT_CONCURRENCY=complete
xcodebuild build -project ScrollDirection.xcodeproj -scheme ScrollDirection -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ScrollDirectionReleaseDerivedData
codesign --verify --deep --strict --verbose=2 /tmp/ScrollDirectionReleaseDerivedData/Build/Products/Release/ScrollDirection.app
~~~

Expected: TEST SUCCEEDED、BUILD SUCCEEDED 与代码签名验证成功。

- [ ] **Step 4: 用已验证 Release 构建覆盖本项目的 Debug 安装**

先确认现有安装的 bundle identifier：

~~~bash
plutil -extract CFBundleIdentifier raw /Applications/ScrollDirection.app/Contents/Info.plist
~~~

Expected: com.weiyu1218.ScrollDirection。退出当前 ScrollDirection 后运行：

~~~bash
ditto /tmp/ScrollDirectionReleaseDerivedData/Build/Products/Release/ScrollDirection.app /Applications/ScrollDirection.app
codesign --verify --deep --strict --verbose=2 /Applications/ScrollDirection.app
open /Applications/ScrollDirection.app
~~~

Expected: Release 应用启动，既有权限仍对应同一 bundle identifier 与签名要求，菜单状态和两类滚动方向继续通过。

- [ ] **Step 5: 确认仓库清洁**

Run:

~~~bash
git status --short
git ls-files | rg 'xcuserdata|xcuserstate|DerivedData|\.DS_Store'
~~~

Expected: git status 无输出，第二条命令无输出。若真实缺陷产生修复，必须先运行受影响测试、审查暂存差异，再以 fix: 中文描述创建独立提交。

### Task 11: 发布到公开 GitHub 仓库并创建 Draft PR

**Files:**
- No source changes.
- Create remote repository: github.com/weiyu1218/ScrollDirection

**Interfaces:**
- Consumes: 清洁的 feature/scroll-direction-app 分支和 GitHub CLI 登录状态。
- Produces: Public 仓库、main 分支、feature 分支和未合并的 Draft PR。

- [ ] **Step 1: 验证公开身份与远程状态**

Run:

~~~bash
gh auth status
git config user.name
git config user.email
git log --all --format='%an <%ae>' | sort -u
git remote -v
~~~

Expected: GitHub 账号为 weiyu1218；本地作者为 weiyu1218 与 223638148+weiyu1218@users.noreply.github.com；历史中没有其他作者邮箱；创建仓库前没有 origin。

- [ ] **Step 2: 最后确认分支和测试证据**

Run:

~~~bash
git status --short --branch
git log --oneline main..feature/scroll-direction-app
xcodebuild test -project ScrollDirection.xcodeproj -scheme ScrollDirection -destination 'platform=macOS,arch=arm64' SWIFT_STRICT_CONCURRENCY=complete
~~~

Expected: 当前分支为 feature/scroll-direction-app，工作区清洁，功能提交存在，测试再次显示 TEST SUCCEEDED。

- [ ] **Step 3: 创建 Public 仓库**

Run:

~~~bash
gh repo create weiyu1218/ScrollDirection --public --source=. --remote=origin
gh repo view weiyu1218/ScrollDirection --json nameWithOwner,visibility,url
~~~

Expected: nameWithOwner 为 weiyu1218/ScrollDirection，visibility 为 PUBLIC。

- [ ] **Step 4: 推送 main 与 feature 分支**

Run:

~~~bash
git push -u origin main
git push -u origin feature/scroll-direction-app
~~~

Expected: 两个分支首次推送成功，不使用 force push。

- [ ] **Step 5: 创建 Draft PR**

Run:

~~~bash
gh pr create --draft --base main --head feature/scroll-direction-app --title "feat: 支持鼠标与触控板独立滚动方向" --body $'## Summary\n- 在系统自然滚动开启时，仅反转离散鼠标的垂直滚动\n- 保持触控板连续与惯性滚动原样\n- 提供菜单栏状态、权限引导和登录时启动\n\n## Verification\n- Swift Testing 全部通过\n- Swift 6 严格并发构建通过\n- Release 代码签名验证通过\n- GPW2 continuousValue 为 0，内置触控板为非 0\n- 标准应用、接收器重连、睡眠唤醒、重新登录和权限撤销验收通过'
gh pr view --json url,isDraft,baseRefName,headRefName,state
~~~

Expected: isDraft 为 true，baseRefName 为 main，headRefName 为 feature/scroll-direction-app。计划不自动合并 PR；合并由用户在审阅公开差异后决定。
