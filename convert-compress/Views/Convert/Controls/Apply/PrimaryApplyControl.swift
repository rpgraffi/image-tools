import SwiftUI

struct PrimaryApplyControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @State private var showDoneText: Bool = false
    
    var body: some View {
        // vm states (we could construct the state with an enum like PrimaryApplyControlState: disabled, progressing, active, done)
        let isDisabled: Bool = vm.images.isEmpty
        let isInProgress: Bool = vm.isExporting
        let progress: Double = vm.exportFraction
        let counterText: String? = vm.isExporting ? "\(vm.exportCompleted)/\(vm.exportTotal)" : nil
        let ingestText: String? = vm.ingestCounterText
        let ingestProgress: Double = vm.ingestFraction
        
        let height: CGFloat = 40
        let progressWidth: CGFloat = 200
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
            .padding(.horizontal, 20)
            .frame(width: (isInProgress || ingestText != nil) ? progressWidth : nil, height: height)
            .frame(minWidth: height)
            .background {
                ZStack(alignment: .leading) {
                    // Background
                    Color.secondary.opacity(0.2)
                    
                    // Full accent color when active, or progress fill when in progress
                    if isInProgress || ingestText != nil {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: displayedProgress * proxy.size.width)
                        }
                    } else if !isDisabled {
                        Color.accentColor
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
            .contentShape(Rectangle())
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .shadow(color: Color.accentColor.opacity((isDisabled || isInProgress || ingestText != nil) ? 0 : 0.25), radius: 8, x: 0, y: 2)
        .disabled(isDisabled || ingestText != nil)
        .allowsHitTesting(!isInProgress && ingestText == nil)
        .help(String(localized: "Save images"))
        .onChange(of: isInProgress) { _, isNowInProgress in
            if !isNowInProgress {
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
                showDoneText = false
            }
        }
        .animation(Theme.Animations.spring(), value: isInProgress)
        .animation(Theme.Animations.spring(), value: showDoneText)
        .animation(Theme.Animations.spring(), value: ingestText)
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
