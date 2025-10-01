import SwiftUI

struct ComparisonHostView: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    let asset: ImageAsset

    @State private var sliderPosition: CGFloat = 0.5
    @State private var isHandleHovering: Bool = false
    @State private var isDragging: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var preview: ComparisonPreviewState { vm.comparisonPreview }
    private var fileName: String { asset.originalURL.lastPathComponent }
    private var currentHandleSize: CGFloat { (isHandleHovering || isDragging) ? 46 : 34 }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = proxy.size.height

            ZStack {
                comparisonLayers(width: width, height: height)

                if preview.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                }

                if let error = preview.errorMessage, !preview.isLoading {
                    errorOverlay(text: error)
                }
            }
            .overlay(alignment: .leading) {
                splitHandle(height: height)
                    .offset(x: sliderOffset(width: width))
            }
            .overlay(topBar, alignment: .top)
            .overlay(bottomLabels, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(splitDrag(width: width))
            .onTapGesture { location in
                let normalized = min(max(0, location.x / width), 1)
                withAnimation(.easeOut(duration: 0.18)) { sliderPosition = normalized }
            }
        }
        .onAppear { sliderPosition = 0.5 }
        .animation(.easeInOut(duration: 0.15), value: isHandleHovering)
    }

    private func comparisonLayers(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            imageLayer(for: preview.originalImage)

            if let processed = preview.processedImage {
                imageLayer(for: processed)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: sliderPosition * width)
                            .frame(maxHeight: .infinity, alignment: .leading)
                    }
                    .animation(.linear(duration: isDragging ? 0 : 0.18), value: sliderPosition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35))
        .clipped()
    }

    private func imageLayer(for nsImage: NSImage?) -> some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Color.secondary.opacity(0.18)
            }
        }
    }

    private func splitHandle(height: CGFloat) -> some View {
        let size = currentHandleSize
        return ZStack {
            RoundedRectangle(cornerRadius: 0.75)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.45 : 0.7))
                .frame(width: 2, height: height)
                .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)

            Circle()
                .fill(Color.accentColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "chevron.left.slash.chevron.right")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
                .onHover { hovering in isHandleHovering = hovering }
        }
    }

    private func splitDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let normalized = min(max(0, value.location.x / width), 1)
                sliderPosition = normalized
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let size = asset.originalPixelSize {
                    Text("Original: \(Int(size.width)) × \(Int(size.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            CircleIconButton(action: { vm.dismissComparison() }) {
                Image(systemName: "xmark")
            }
            .help(String(localized: "Close comparison"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
        .padding(16)
    }

    private var bottomLabels: some View {
        HStack {
            comparisonChip(title: String(localized: "Original"))
            Spacer()
            comparisonChip(title: String(localized: "Preview"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func comparisonChip(title: String) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private func errorOverlay(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 6)
    }

    private func sliderOffset(width: CGFloat) -> CGFloat {
        (sliderPosition * width) - (currentHandleSize / 2)
    }
}

#Preview("Comparison Host") {
    ComparisonHostPreview.makeLoaded()
        .frame(width: 720, height: 420)
        .padding()
}

#Preview("Comparison Loading") {
    ComparisonHostPreview.makeLoading()
        .frame(width: 600, height: 360)
        .padding()
}

private enum ComparisonHostPreview {
    @MainActor
    static func makeLoaded() -> some View {
        let vm = ImageToolsViewModel()
        let asset = makeMockAsset(fileName: "Sample.png")
        vm.images = [asset]
        vm.comparisonSelection = ComparisonSelection(assetID: asset.id)
        vm.comparisonPreview = ComparisonPreviewState(
            originalImage: gradientImage(colors: [.systemBlue, .systemTeal]),
            processedImage: gradientImage(colors: [.systemOrange, .systemPink]),
            isLoading: false,
            errorMessage: nil
        )
        return ComparisonHostView(asset: asset)
            .environmentObject(vm)
    }

    @MainActor
    static func makeLoading() -> some View {
        let vm = ImageToolsViewModel()
        let asset = makeMockAsset(fileName: "Processing.png")
        vm.images = [asset]
        vm.comparisonSelection = ComparisonSelection(assetID: asset.id)
        vm.comparisonPreview = ComparisonPreviewState(
            originalImage: gradientImage(colors: [.systemPurple, .systemIndigo]),
            processedImage: nil,
            isLoading: true,
            errorMessage: nil
        )
        return ComparisonHostView(asset: asset)
            .environmentObject(vm)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private static func makeMockAsset(fileName: String) -> ImageAsset {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var asset = ImageAsset(url: url)
        asset.originalPixelSize = CGSize(width: 1920, height: 1280)
        return asset
    }

    private static func gradientImage(colors: [NSColor]) -> NSImage {
        let size = NSSize(width: 800, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        let gradient = NSGradient(colors: colors) ?? NSGradient(starting: .systemGray, ending: .systemGray)
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 0)
        image.unlockFocus()
        return image
    }
}


