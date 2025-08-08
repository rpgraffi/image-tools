import SwiftUI
import AppKit

struct CompressControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    @FocusState private var kbFieldFocused: Bool
    @FocusState private var percentFieldFocused: Bool

    @State private var isEditingPercent: Bool = false
    @State private var percentString: String = "80"

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                GeometryReader { geo in
                    let size = geo.size
                    Group {
                        switch vm.compressionMode {
                        case .percent:
                            percentPill(containerSize: size)
                                .transition(.opacity)
                        case .targetKB:
                            kbField(containerSize: size)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)

            CircleIconButton(action: toggleMode) {
                Text(vm.compressionMode == .percent ? "KB" : "%")
            }
            .frame(minHeight: controlHeight, maxHeight: controlHeight)
            .animation(Theme.Animations.spring(), value: vm.compressionMode)
        }
        .onAppear {
            percentString = String(Int(vm.compressionPercent * 100))
        }
        .onChange(of: percentFieldFocused) { _, focused in
            if !focused && isEditingPercent {
                commitPercentFromString()
                isEditingPercent = false
            }
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if percentFieldFocused && isEditingPercent {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }

    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            vm.compressionMode = (vm.compressionMode == .percent) ? .targetKB : .percent
        }
    }

    private func percentPill(containerSize: CGSize) -> some View {
        let width = containerSize.width
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let progress = CGFloat(min(max(vm.compressionPercent, 0.0), 1.0))
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Colors.accentGradientStart, Theme.Colors.accentGradientEnd], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(0, width * progress))
                .animation(Theme.Animations.pillFill(), value: vm.compressionPercent)

            HStack(spacing: 4) {
                if isEditingPercent {
                    TextField("", text: $percentString)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .focused($percentFieldFocused)
                        .frame(maxWidth: .infinity)
                        .onSubmit { commitPercentFromString(); isEditingPercent = false; percentFieldFocused = false; NSApp.keyWindow?.endEditing(for: nil) }
                        .onChange(of: percentString) { _, newValue in
                            let digits = newValue.filter { $0.isNumber }
                            if digits != percentString { percentString = digits }
                        }
                    Text("%")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text("\(Int(vm.compressionPercent * 100))%")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditingPercent = true
                            percentString = String(Int(vm.compressionPercent * 100))
                            percentFieldFocused = true
                        }
                }
            }
            .padding(.horizontal, 12)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { value in
                if isEditingPercent || percentFieldFocused { return }
                let x = min(max(0, value.location.x), width)
                let raw = Double(x / width)
                let clamped = max(0.05, min(1.0, raw))
                let stepped = (clamped * 100).rounded() / 100.0
                vm.compressionPercent = stepped
            }
        )
    }

    private func kbField(containerSize: CGSize) -> some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            HStack(spacing: 6) {
                TextField("Target KB", text: $vm.compressionTargetKB)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .focused($kbFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); kbFieldFocused = false }
                    .onChange(of: vm.compressionTargetKB) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != vm.compressionTargetKB { vm.compressionTargetKB = digits }
                    }
                Text("KB")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.fieldAffordanceLabel)
            }
            .padding(.horizontal, 12)
        }
        .onChange(of: kbFieldFocused) { _, focused in
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if kbFieldFocused {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }

    private func commitPercentFromString() {
        let parsed = Int(percentString) ?? Int(vm.compressionPercent * 100)
        let clamped = max(5, min(100, parsed))
        percentString = String(clamped)
        vm.compressionPercent = Double(clamped) / 100.0
    }
} 