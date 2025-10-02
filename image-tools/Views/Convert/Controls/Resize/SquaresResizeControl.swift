import SwiftUI
import AppKit

/// UI for formats that only support a fixed set of square sizes (e.g., ICNS/ICO).
/// Uses a discrete pill slider across allowed sizes and a menu to pick exact size.
struct SquaresResizeControl: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    let allowedSizes: [Int] // sorted ascending
    @State private var menuHandler: MenuHandler?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let corner = Theme.Metrics.pillCornerRadius(forHeight: size.height)
            discretePercentPill(containerSize: size, corner: corner, sizes: allowedSizes)
                .onTapGesture {
                    showSizesMenuAtMouseLocation(sizes: allowedSizes)
                }
        }
    }

    private func sizesMenu(_ sizes: [Int]) -> some View {
        Group {
            ForEach(sizes, id: \.self) { s in
                Button("\(s)x\(s)") { selectSquare(s) }
            }
        }
    }

    private func selectSquare(_ side: Int) {
        vm.sizeUnit = .pixels
        vm.resizeWidth = String(side)
        vm.resizeHeight = String(side)
        if let asset = (vm.images.first) ?? vm.images.first,
           let base = asset.originalPixelSize, base.width > 0, base.height > 0 {
            let scale = Double(side) / Double(min(base.width, base.height))
            vm.resizePercent = max(0.01, min(1.0, scale))
        }
    }

    private func discretePercentPill(containerSize: CGSize, corner: CGFloat, sizes: [Int]) -> some View {
        let progress = valueToProgress(sizes: sizes)
        return ZStack(alignment: .leading) {
            PillBackground(
                containerSize: containerSize,
                cornerRadius: corner,
                progress: progress,
                // For fixed-size controls we always want the pill filled; never fade out at max
                fadeStart: 2.0
            )
            HStack(spacing: 8) {
                Text(String(localized: "Resize"))
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(currentSizeLabel(sizes: sizes))
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Theme.Animations.fastSpring(), value: progress)
            }
            .padding(.horizontal, 12)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let width = max(containerSize.width, 1)
                    let x = min(max(0, value.location.x), width)
                    let p = Double(x / width)
                    progressToNearestValue(p, sizes: sizes)
                }
        )
    }

    private func currentSizeLabel(sizes: [Int]) -> String {
        let w = Int(vm.resizeWidth) ?? 0
        let h = Int(vm.resizeHeight) ?? 0
        if w == h && sizes.contains(w) { return "\(w)x\(h)" }
        let nearest = sizes.min(by: { abs($0 - w) < abs($1 - w) }) ?? sizes.first ?? 0
        return "\(nearest)x\(nearest)"
    }

    private func valueToProgress(sizes: [Int]) -> Double {
        let current = Int(vm.resizeWidth) ?? sizes.first ?? 0
        guard let idx = sizes.firstIndex(of: current), sizes.count > 1 else { return 0 }
        return Double(idx) / Double(sizes.count - 1)
    }

    private func progressToNearestValue(_ p: Double, sizes: [Int]) {
        let count = max(sizes.count, 1)
        let idx = Int((p * Double(count - 1)).rounded())
        let side = sizes[min(max(0, idx), count - 1)]
        selectSquare(side)
    }

    private func showSizesMenuAtMouseLocation(sizes: [Int]) {
        let handler = MenuHandler { side in
            selectSquare(side)
            self.menuHandler = nil
        }
        self.menuHandler = handler

        let menu = NSMenu()
        for s in sizes {
            let item = NSMenuItem(title: "\(s)x\(s)", action: #selector(MenuHandler.handleSelect(_:)), keyEquivalent: "")
            item.target = handler
            item.tag = s
            menu.addItem(item)
        }

        let screenPoint = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }
}

private final class MenuHandler: NSObject {
    let onSelect: (Int) -> Void
    init(onSelect: @escaping (Int) -> Void) { self.onSelect = onSelect }
    @objc func handleSelect(_ sender: NSMenuItem) { onSelect(sender.tag) }
}


