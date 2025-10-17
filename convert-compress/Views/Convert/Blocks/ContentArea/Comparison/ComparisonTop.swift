import SwiftUI

struct ComparisonTop: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    let asset: ImageAsset
    let heroNamespace: Namespace.ID
    @Binding var sliderPosition: CGFloat
    @ObservedObject var zoomPanState: ZoomPanState
    
    @State private var showZoomBadge: Bool = false
    @State private var zoomBadgeHideTask: Task<Void, Never>?
    
    private var fileName: String {
        asset.originalURL.lastPathComponent
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            SingleLineOverlayBadge(text: fileName)
                .matchedGeometryEffect(
                    id: "filename-\(asset.id)",
                    in: heroNamespace
                )
            
            SingleLineOverlayBadge(text: "\(zoomPanState.zoomPercent)%")
                .opacity(showZoomBadge ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showZoomBadge)
            
            Spacer()
            
            Button(action: {
                sliderPosition = sliderPosition < 0.5 ? 1.0 : 0.0
            }) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                    Image(systemName: sliderPosition < 0.99 ? "inset.filled.righthalf.lefthalf.rectangle" : "inset.filled.lefthalf.righthalf.rectangle")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .help(sliderPosition < 0.5 ? String(localized: "Show processed image") : String(localized: "Show original image"))
            
            Button(action: { vm.dismissComparison() }) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .help(String(localized: "Close comparison"))
        }
        .padding(16)
        .onChange(of: zoomPanState.scale) { _, _ in
            // Show badge when zooming
            showZoomBadge = true
            
            // Cancel existing hide task
            zoomBadgeHideTask?.cancel()
            
            // Schedule new hide task for 3 seconds
            zoomBadgeHideTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    showZoomBadge = false
                }
            }
        }
        .onDisappear {
            zoomBadgeHideTask?.cancel()
        }
    }
}

