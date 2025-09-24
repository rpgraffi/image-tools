import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchase: PurchaseManager
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                // Free panel
                VStack() {
                    VStack(spacing: 6) {
                        Text(String(localized:"Free"))
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(String(localized:"during early stage"))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onContinue) {
                        Text(String(localized:"Continue"))
                            .font(.system(size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(4)
                    }
                    .foregroundStyle(.secondary)
                    .buttonBorderShape(.capsule)
                }
                .padding(.horizontal, 8)
                .padding(.top, 32)
                .padding(.bottom, 8)
                .frame(minWidth: 320, minHeight: 280)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder( LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
                
                // Lifetime panel
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("\(String(localized: "Once")) \(purchase.lifetimeDisplayPrice ?? "—")")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(String(localized:"Discount for early users"))
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.9))
                        if let compareAt = purchase.lifetimeRegularDisplayPrice {
                            Text(compareAt)
                                .strikethrough()
                                .foregroundStyle(.white.opacity(0.6))
                                .font(.system(size: 16))
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Label(String(localized:"Unlimited conversions"), systemImage: "photo.stack.fill").font(.system(size: 16))
                        Label(String(localized:"All future updates"), systemImage: "arrow.down.app.fill").font(.system(size: 16))
                        Label(String(localized:"Made in Europe"), systemImage: "globe.europe.africa.fill").font(.system(size: 16))
                    }
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)
                    
                    Spacer()
                    Button(action: { Task { await purchase.purchaseLifetime() } }) {
                        Text(String(localized:"Get Lifetime"))
                            .font(.system(size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(4)
                    }
                    .disabled(purchase.isPurchasing)
                    .tint(.white.opacity(0.9))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 8)
                .padding(.top, 32)
                .padding(.bottom, 8)
                .frame(minWidth: 360, minHeight: 280)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder( LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
            }
            
            HStack(spacing: 24) {
                Button(action: { Task { await purchase.restorePurchases() } }) {
                    Text(String(localized:"Restore Purchases"))
                }
                Link(String(localized:"Privacy"), destination: URL(string: "https://imagetools.app/privacy")!)
                Link(String(localized:"Terms"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link(String(localized:"Source Code"), destination: URL(string: "https://github.com/rpgraffi/image-tools")!)
                Link(String(localized:"Help"), destination: URL(string: "https://imagetools.app/help")!)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        
        .frame(minWidth: 760, minHeight: 420)
        .alert(item: Binding(
            get: { purchase.purchaseError.map { LocalizedErrorWrapper(message: $0) } },
            set: { _ in purchase.purchaseError = nil }
        )) { wrapper in
            Alert(title: Text(wrapper.message))
        }
        .onChange(of: purchase.isProUnlocked) {
            if purchase.isProUnlocked { onContinue() }
        }
        .background(.regularMaterial)
    }
}

private struct LocalizedErrorWrapper: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    PaywallView(purchase: PurchaseManager.shared, onContinue: {})
}


