import SwiftUI

struct TopBar: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack {
            Spacer()
            
            // Titlebar content on trailing side
            HStack(spacing: 8) {
                Text(isHovered ? "Converted: \(vm.totalImageConversions)" : "\(vm.totalImageConversions)")
                    .font(.system(.caption, design: .monospaced))
                    // .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.18), value: isHovered)
                    .frame(minWidth: 130, alignment: .trailing)
                    .onHover { hovering in
                        isHovered = hovering
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
                        // .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                // .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.secondary)
        .frame(height: 56)
        .padding(.trailing, 16)
        .padding(.leading, 70) // Traffic Lights Padding
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

