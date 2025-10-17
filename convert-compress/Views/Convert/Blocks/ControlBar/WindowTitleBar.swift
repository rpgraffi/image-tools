import SwiftUI

struct WindowTitleBar: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(isHovered ? "Converted: \(vm.totalImageConversions)" : "\(vm.totalImageConversions)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 130, alignment: .trailing)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isHovered = hovering
                    }
                }
            
            Menu {
                if !purchaseManager.isProUnlocked {
                    Button {
                        vm.paywallContext = .manual
                        vm.isPaywallPresented = true
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
                
                Link(destination: URL(string: "https://convert-compress.com")!) {
                    Label("Website", systemImage: "globe")
                }
                
                ShareLink(item: URL(string: "https://convert-compress.com")!) {
                    Label("Share App", systemImage: "square.and.arrow.up")
                }
                
                Link(destination: URL(string: "https://github.com/rpgraffi/convert-compress")!) {
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

