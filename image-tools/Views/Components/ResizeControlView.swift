import SwiftUI
import AppKit

struct ResizeControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    @State private var isEditingPercent: Bool = false
    @State private var localPercent: Double = 100 // 0...100 UI value

    private let controlHeight: CGFloat = 36
    private let controlMinWidth: CGFloat = 220
    private let controlMaxWidth: CGFloat = 320

    var body: some View {
        HStack(spacing: 8) {
            Text("Resize")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            modeSwitch

            ZStack { // fixed footprint for both modes
                if vm.sizeUnit == .percent {
                    percentPill
                        .transition(.opacity)
                } else {
                    pixelFields
                        .transition(.opacity)
                }
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)
        }
        .onAppear {
            localPercent = max(0, min(100, vm.resizePercent * 100))
        }
        .onChange(of: vm.sizeUnit) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                if newValue == .pixels {
                    vm.prefillPixelsIfPossible()
                }
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 2) {
            CapsuleSegment(label: "%", isSelected: vm.sizeUnit == .percent) {
                if vm.sizeUnit != .percent {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        vm.sizeUnit = .percent
                        localPercent = max(0, min(100, vm.resizePercent * 100))
                    }
                }
            }
            CapsuleSegment(label: "px", isSelected: vm.sizeUnit == .pixels) {
                if vm.sizeUnit != .pixels {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        vm.sizeUnit = .pixels
                        vm.prefillPixelsIfPossible()
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private var percentPill: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let percentProgress = CGFloat(localPercent / 100.0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: controlHeight/2, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: controlHeight/2, style: .continuous)
                    .fill(LinearGradient(colors: [.accentColor.opacity(0.25), .accentColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, width * percentProgress))
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: localPercent)

                HStack {
                    if isEditingPercent {
                        TextField("%", value: Binding(
                            get: { localPercent },
                            set: { newVal in
                                localPercent = min(100, max(0, newVal))
                                vm.resizePercent = localPercent / 100.0
                            }
                        ), format: .number)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .onSubmit { isEditingPercent = false }
                    } else {
                        Text("\(Int(localPercent))%")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { isEditingPercent = true }
                    }
                }
                .padding(.horizontal, 12)
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = min(max(0, value.location.x), width)
                    let p = (x / width) * 100
                    localPercent = Double(p)
                    vm.resizePercent = localPercent / 100.0
                }
            )
        }
    }

    private var pixelFields: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fieldWidth = (width - 12) / 2
            HStack(spacing: 12) {
                PillTextField(text: $vm.resizeWidth, placeholder: "W")
                    .frame(width: fieldWidth, height: controlHeight)
                Text("×").foregroundStyle(.secondary)
                PillTextField(text: $vm.resizeHeight, placeholder: "H")
                    .frame(width: fieldWidth, height: controlHeight)
            }
        }
    }
}

private struct CapsuleSegment: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PillTextField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.headline)
                .padding(.horizontal, 8)
        }
    }
} 