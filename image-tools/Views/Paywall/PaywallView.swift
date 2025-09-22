import SwiftUI

struct PaywallView: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()

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
                        Button(action: { vm.paywallContinueFree() }) {
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
                            Text(String(localized:"Once 9.99 €"))
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(String(localized:"Discount for early users"))
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(String(localized:"14.99 €"))
                                .strikethrough()
                                .foregroundStyle(.white.opacity(0.6))
                                .font(.system(size: 16))
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
                        Button(action: { vm.paywallPurchaseLifetime() }) {
                            Text(String(localized:"Get Lifetime"))
                                .font(.system(size: 18))
                                .frame(maxWidth: .infinity)
                                .padding(4)
                        }
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
                    Button(String(localized:"Recover")) { vm.openSupportURL(.recover) }
                    Button(String(localized:"Privacy")) { vm.openSupportURL(.privacy) }
                    Button(String(localized:"Open Source")) { vm.openSupportURL(.openSource) }
                    Button(String(localized:"Help")) { vm.openSupportURL(.help) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(minWidth: 760, minHeight: 420)
    }
}

#Preview {
    PaywallView(vm: ImageToolsViewModel())
}


