import SwiftUI
import AppKit

/// 应用委托：
/// 1. 确保菜单栏应用关闭窗口后不退出
/// 2. 用 NSStatusItem + NSPopover 自实现菜单栏项和弹窗，
///    NSPopover 系统自带半透明磨砂玻璃质感，MenuBarExtra(.window) 无法实现
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    /// 用 EventMonitor 监听点击 popover 外部区域以关闭弹窗，与系统 popover 行为一致
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏应用：设为 accessory 模式，不在 Dock 显示图标，只通过菜单栏交互
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 菜单栏常驻应用：关闭最后一个窗口（如设置窗口）后不应退出
        return false
    }

    // MARK: - 菜单栏项
    private func setupStatusItem() {
        // autosaveName 让系统记住菜单栏项位置，重启后保持
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item
        updateStatusBarTitle()

        // 监听 appState 变化刷新菜单栏标题
        // 用 NotificationCenter 接收余额更新通知（避免 AppDelegate 直接持有 ObservableObject）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusBarTitle),
            name: NSNotification.Name("AppStateChanged"),
            object: nil
        )
    }

    @objc private func updateStatusBarTitle() {
        guard let button = statusItem?.button else { return }
        // @objc 方法不是 main actor 隔离的，用 MainActor.assumeIsolated 访问 AppState 属性
        MainActor.assumeIsolated {
            let state = AppState.shared
            let isLow = state.isLowBalance
            let balance = state.totalBalance
            self.renderStatusBarTitle(button: button, isLow: isLow, balance: balance)
        }
    }

    /// 渲染菜单栏按钮内容：图标 + 余额文本
    private func renderStatusBarTitle(button: NSStatusBarButton, isLow: Bool, balance: Decimal?) {
        // 余额文本
        let title: String
        if let balance = balance {
            let value = NSDecimalNumber(decimal: balance).doubleValue
            title = "¥" + String(format: "%.2f", value)
        } else {
            title = "¥--"
        }

        if isLow {
            // 余额不足：红色警示图标 + 红色文本
            // 用 SF Symbols 的 exclamationmark.circle.fill，设为 template 后用 contentTintColor 上色
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let warningIcon = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)?
                .copy() as? NSImage
            warningIcon?.isTemplate = true
            button.image = warningIcon
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
            // contentTintColor 给 template image 上色为红色
            button.contentTintColor = .systemRed
            // 文本用 attributedTitle 设置红色，title 属性无法控制颜色
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ])
        } else {
            // 余额充足：恢复默认 contentTintColor，让 template image 按系统色渲染
            button.contentTintColor = nil
            // 余额充足：HowLeft HL 图标 + 普通文本
            // NSStatusBarButton 原生支持 image + title 组合，imagePosition 控制布局
            // 比 attributedTitle + NSTextAttachment 更可靠：图标垂直居中，template image 自动适配深浅色
            button.image = Self.makeTemplateImage(named: "howleft-menu-icon", size: 20)
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ])
        }
    }

    /// 加载资源图片并按指定尺寸渲染为 template NSImage
    /// - Parameters:
    ///   - named: Asset catalog 中的图片名
    ///   - size: 目标尺寸（pt），菜单栏图标建议 18-20
    /// - Returns: 模板渲染的 NSImage，自动适配深浅色
    private static func makeTemplateImage(named: String, size: CGFloat) -> NSImage? {
        guard let base = NSImage(named: named) else { return nil }
        // 创建指定尺寸的副本，标记为 template 以适配深浅色
        let target = NSImage(size: NSSize(width: size, height: size))
        target.isTemplate = true
        target.lockFocus()
        base.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        target.unlockFocus()
        return target
    }

    // MARK: - Popover 切换
    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if let popover = popover, popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo positioningView: NSView) {
        let popover = NSPopover()
        // 系统标准弹窗行为：点击外部自动关闭
        popover.behavior = .transient
        popover.animates = true
        // 用 SwiftUI 承载弹窗内容
        let hosting = NSHostingController(
            rootView: PopupView()
                .environmentObject(AppState.shared)
        )
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 332, height: 240)
        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .minY)
        self.popover = popover

        // 激活应用，确保弹窗内控件（如按钮）响应点击
        NSApp.activate(ignoringOtherApps: true)

        // 启动全局事件监听，点击弹窗外部时关闭（transient 行为已内置，这里作为额外保障）
        startEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        // 监听全局鼠标点击事件，点击弹窗外部时关闭 popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
            self?.stopEventMonitor()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

@main
struct HowLeftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // 用 shared 单例：AppDelegate 和 SwiftUI Scene 共享同一份状态
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // 设置窗口：用 Settings scene，只在 openWindow 调用时显示，不会在启动时自动弹出
        // （之前用普通 Window 会在启动时自动创建并显示）
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
