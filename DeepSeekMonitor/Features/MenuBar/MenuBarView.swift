import SwiftUI
import AppKit

/// 菜单栏标签视图（图标 + CNY 余额文本）
/// 菜单栏只显示 CNY 余额总和，弹窗才显示双币种
struct MenuBarLabel: View {
    let cnyBalance: Decimal?
    let isLow: Bool

    var body: some View {
        HStack(spacing: 0) {
            // 余额充足：DeepSeek 鲸鱼图标（template image，系统自动适配深浅色）
            // 余额不足：切红色警示图标，提醒用户
            if isLow {
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.red)
            } else {
                // MenuBarExtra label 的 NSStatusBarButton 会忽略 HStack spacing、Spacer、padding，
                // 唯一可靠方法是在 NSImage 位图层面把右侧间距画进去：
                // NSImage size 设为 (20+4, 20)，图标画在左侧 (0,0)，右侧 4pt 留透明像素
                Image(nsImage: Self.makeTemplateImage(named: "deepseek-menu-icon", size: 20, trailingPadding: 4))
                    .foregroundStyle(.primary)
            }
            Text(formattedCNY)
                .foregroundStyle(isLow ? .red : .primary)
                .font(.system(size: 13, weight: .medium))
        }
    }

    /// 加载资源图片并按指定尺寸渲染为 template NSImage
    /// - Parameters:
    ///   - named: Asset catalog 中的图片名
    ///   - size: 目标尺寸（pt），菜单栏图标建议 18-20
    ///   - trailingPadding: 图标右侧透明间距（pt），用于在 status bar 中撑开图标和文本的距离
    /// - Returns: 模板渲染的 NSImage
    private static func makeTemplateImage(named: String, size: CGFloat, trailingPadding: CGFloat = 0) -> NSImage {
        guard let base = NSImage(named: named) else {
            return NSImage()
        }
        // 画布宽度 = 图标尺寸 + 右侧间距，高度 = 图标尺寸
        let canvasWidth = size + trailingPadding
        let target = NSImage(size: NSSize(width: canvasWidth, height: size))
        target.isTemplate = true
        target.lockFocus()
        // 图标画在画布左侧 (0, 0)，右侧 trailingPadding 宽度保持透明
        base.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        target.unlockFocus()
        return target
    }

    /// CNY 余额格式化：¥12.34，未加载时 ¥--
    private var formattedCNY: String {
        guard let balance = cnyBalance else { return "¥--" }
        let value = NSDecimalNumber(decimal: balance).doubleValue
        return "¥" + String(format: "%.2f", value)
    }
}
