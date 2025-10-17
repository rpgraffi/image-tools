import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentArea: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @State private var isDropping: Bool = false
    
    // Layout
    private let tileMaxWidth: CGFloat = 300
    private let gridSpacing: CGFloat = 12
    private let cornerRadius: CGFloat = 20
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 220, maximum: tileMaxWidth), spacing: gridSpacing, alignment: .top)]
    }
    
    private var allImages: [ImageAsset] { vm.images }
    private var isEmpty: Bool { allImages.isEmpty }
    
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var heroNamespace
    
    var body: some View {
        HStack { content }
            .padding(8)
            .frame(minWidth: 420, minHeight: 260)
            .contentShape(Rectangle())
            .onDrop(of: [.image, .fileURL, .folder, .directory], isTargeted: $isDropping, perform: handleProviderDrop)
            .onChange(of: isDropping) { _, hovering in
                if hovering { Haptics.generic() }
                else { Haptics.alignment() }
            }
    }
    
    
    private var content: some View {
        ZStack {
            if isEmpty {
                ImagesListEmptyState(
                    onPaste: { vm.addFromPasteboard() },
                    onPickFromFinder: {
                        IngestionCoordinator.presentOpenPanel { urls in
                            vm.addURLs(urls)
                        }
                    }
                )
            } else {
                ImagesGridView(
                    images: allImages,
                    columns: columns,
                    heroNamespace: heroNamespace
                )
            }
            
            if let selection = vm.comparisonSelection,
               let asset = vm.images.first(where: { $0.id == selection.assetID }) {
                ComparisonView(asset: asset, heroNamespace: heroNamespace)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vm.comparisonSelection != nil)
        .background(containerBackground())
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(containerOverlay())
    }
    
    private func containerBackground() -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(colorScheme == .dark ? 0.15 : 0.06))
    }
    
    private func containerOverlay() -> some View {
        let strokeColorDark = LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.15)], startPoint: .top, endPoint: .bottom)
        let strokeColorLight = LinearGradient(colors: [Color.black.opacity(0.08), Color.white.opacity(0.32)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(colorScheme == .dark ? strokeColorDark : strokeColorLight, lineWidth: 0.8)
            
            // Inner shadow: bottom shade
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.60 : 0.20), lineWidth: 1.5)
                .blur(radius: 6)
                .offset(y: 3)
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            
            if isEmpty || isDropping {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .foregroundStyle(isDropping ? Color.accentColor.blendMode(.normal) : colorScheme == .dark ?  Color.white.opacity(0.25).blendMode(.lighten) : Color.black.opacity(0.20).blendMode(.darken))
            }
        }
        .allowsHitTesting(false)
    }
    
    private func handleProviderDrop(_ providers: [NSItemProvider]) -> Bool {
        guard IngestionCoordinator.canHandle(providers: providers) else { return false }
        vm.addProvidersStreaming(providers, batchSize: 16)
        return true
    }
    
    
}
