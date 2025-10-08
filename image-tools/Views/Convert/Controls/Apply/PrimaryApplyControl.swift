import SwiftUI

struct PrimaryApplyControl: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    @State private var labelSize: CGSize = .zero
    @State private var showDoneText: Bool = false
    
    var body: some View {
        // vm states
        let isDisabled: Bool = vm.images.isEmpty
        let isInProgress: Bool = vm.isExporting
        let progress: Double = vm.exportFraction
        let counterText: String? = vm.isExporting ? "\(vm.exportCompleted)/\(vm.exportTotal)" : nil
        let ingestText: String? = vm.ingestCounterText
        let ingestProgress: Double = vm.ingestFraction
        
        let height: CGFloat = 40
        let horizontalPadding: CGFloat = 20
        let maxWidth: CGFloat = 160
        
        let huggedWidth = max(labelSize.width + horizontalPadding * 2, height)
        let targetWidth = (isInProgress || ingestText != nil) ? maxWidth : min(maxWidth, huggedWidth)
        let label: String = {
            if let ingestText {
                return ingestText
            }
            if isInProgress {
                return counterText ?? String(localized: "Save")
            }
            if showDoneText {
                return String(localized: "Done")
            }
            return String(localized: "Save")
        }()
        let iconName: String = {
            if ingestText != nil {
                return "arrow.down.app.dashed"
            }
            if isInProgress {
                return "hourglass"
            }
            if showDoneText {
                return "checkmark.rectangle.stack.fill"
            }
            return "photo.stack.fill"
        }()
        let isCounting = ingestText != nil || (isInProgress && (counterText != nil))
        let textTransition: ContentTransition = isCounting ? .numericText() : .opacity
        let displayedProgress: Double = {
            if let _ = ingestText {
                return max(min(ingestProgress, 1.0), 0.0)
            }
            if isInProgress {
                return max(min(progress, 1.0), 0.0)
            }
            return 1.0
        }()
        
        Button(role: .none) {
            guard !isInProgress && ingestText == nil else { return }
            vm.applyPipelineAsync()
        } label: {
            ZStack(alignment: .leading) {
                // Progress fill
                GeometryReader { proxy in
                    // Default: 100% fill; when saving or ingesting, animating to current progress
                    let w = displayedProgress * proxy.size.width
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: w)
                        .animation(Theme.Animations.spring(), value: displayedProgress)
                }
                .frame(height: height) // constrain GeometryReader to pill height
                .allowsHitTesting(false)
                
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .contentTransition(.symbolEffect(.replace))
                    Text(label)
                        .contentTransition(textTransition)
                        .transition(.opacity)
                        .monospacedDigit()
                }
                .font(Theme.Fonts.button)
                .foregroundStyle(Color.white)
                .frame(height: height)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .center)
                // Measure intrinsic label size to hug width in default state
                // TODO: Refactor (Simplify)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: proxy.size)
                    }
                )
                .onPreferenceChange(SizePreferenceKey.self) { newSize in
                    if labelSize != newSize {
                        labelSize = newSize
                    }
                }
                // Drive numeric content transition
                .animation(Theme.Animations.spring(), value: counterText)
                .animation(Theme.Animations.spring(), value: ingestText)
            }
            .frame(width: targetWidth, height: height)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .background(.secondary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
        .frame(maxWidth: maxWidth)
        .disabled(isDisabled || ingestText != nil)
        .allowsHitTesting(!isInProgress && ingestText == nil)
        .shadow(color: Color.accentColor.opacity((isDisabled || isInProgress || ingestText != nil) ? 0 : 0.25), radius: 8, x: 0, y: 2)
        .help(String(localized: "Save images"))
        .onChange(of: isInProgress) { _, isNowInProgress in
            if isNowInProgress == false {
                // Show "Done" briefly when progress finishes
                withAnimation(Theme.Animations.spring()) {
                    showDoneText = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    withAnimation(Theme.Animations.spring()) {
                        showDoneText = false
                    }
                }
            } else {
                // Reset immediately when starting again
                withAnimation(Theme.Animations.spring()) {
                    showDoneText = false
                }
            }
        }
        .animation(Theme.Animations.spring(), value: isInProgress)
        .animation(Theme.Animations.spring(), value: showDoneText)
        .animation(Theme.Animations.spring(), value: ingestText)
        .animation(Theme.Animations.spring(), value: ingestProgress)
    }
} 

// PreferenceKey to measure child size
private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        // Prefer the latest non-zero value
        value = next == .zero ? value : next
    }
}


#Preview("PrimaryApplyControl") {
    struct Demo: View {
        @State private var disabled = false
        @State private var inProgress = false
        @State private var progress: Double = 0.0
        @State private var count: Int? = nil
        
        var body: some View {
            VStack(spacing: 20) {
                PrimaryApplyControl()
                
                HStack {
                    Toggle("Disabled", isOn: $disabled)
                    Toggle("In Progress", isOn: $inProgress)
                }
                .toggleStyle(.switch)
                
                HStack(spacing: 12) {
                    Text("Progress")
                    Slider(value: $progress, in: 0...1)
                        .disabled(!inProgress)
                }
                
                HStack(spacing: 12) {
                    Text("Counter")
                    Stepper(value: Binding(get: { count ?? 0 }, set: { count = $0 }), in: 0...10_000) {
                        Text(count.map(String.init) ?? "nil")
                    }
                }
            }
            .padding()
            .frame(width: 400)
        }
    }
    return Demo()
}
