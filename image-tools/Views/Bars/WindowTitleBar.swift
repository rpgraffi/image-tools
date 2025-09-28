import SwiftUI

struct WindowTitleBar: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    @State private var isHovered: Bool = false

    var body: some View {
        Text(isHovered ? "Converted: \(vm.totalImageConversions)" : "\(vm.totalImageConversions)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(minWidth: 130, alignment: .trailing)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHovered = hovering
                }
            }
    }
}


