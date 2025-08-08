import SwiftUI

struct BottomRow: View {
    @ObservedObject var vm: ImageToolsViewModel
    let onPickFromFinder: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Left column
            HStack(spacing: 8) {
                PillButton {
                    vm.addFromPasteboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                PillButton {
                    onPickFromFinder()
                } label: {
                    Label("Add from Finder", systemImage: "folder.badge.plus")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center column
            applyPrimaryButton()
                .frame(maxWidth: .infinity)

            // Right column
            HStack(spacing: 8) {
                PillButton(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(vm.newImages.isEmpty && vm.editedImages.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(8)
    }

    private func applyPrimaryButton() -> some View {
        let height: CGFloat = max(Theme.Metrics.controlHeight, 40)
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        return Button(role: .none) {
            vm.applyPipeline()
        } label: {
            Label("Apply", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(minWidth: 140, minHeight: height)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.accentColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .disabled(vm.newImages.isEmpty)
        .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 2)
        .help("Apply processing pipeline")
    }
} 