import SwiftUI

struct WindowTitleBar: View {
    @StateObject private var vm = ImageToolsViewModel()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
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
            
            Menu {
                if !purchaseManager.isProUnlocked {
                    Button {
                        Task {
                            await purchaseManager.purchaseLifetime()
                        }
                    } label: {
                        Label("Buy Lifetime", systemImage: "sparkle")
                    }
                    
                    Divider()
                }
                
                Button {
                    sendFeedbackEmail()
                } label: {
                    Label("Send Feedback", systemImage: "envelope")
                }
                
                Link(destination: URL(string: "https://www.image-tool.app")!) {
                    Label("Website", systemImage: "globe")
                }
                
                ShareLink(item: URL(string: "https://www.image-tool.app")!) {
                    Label("Share App", systemImage: "square.and.arrow.up")
                }
                
                Link(destination: URL(string: "https://github.com/rpgraffi/image-tools")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
    
    private func sendFeedbackEmail() {
        let recipient = "me@raffi.studio"
        let subject = "Feedback"
        
        if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mailto:\(recipient)?subject=\(encodedSubject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

