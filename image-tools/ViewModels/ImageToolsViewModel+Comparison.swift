import Foundation
import AppKit
import Combine

// MARK: - Comparison State Models

struct ComparisonSelection: Equatable {
    let assetID: UUID
}

struct ComparisonPreviewState {
    var originalImage: NSImage?
    var processedImage: NSImage?
    var isLoading: Bool
    var errorMessage: String?
    var cropRegion: CGRect?
    var originalSize: CGSize?
    var processedSize: CGSize?

    static let empty = ComparisonPreviewState(
        originalImage: nil,
        processedImage: nil,
        isLoading: false,
        errorMessage: nil,
        cropRegion: nil,
        originalSize: nil,
        processedSize: nil
    )
}

// MARK: - Comparison Logic

extension ImageToolsViewModel {
    // Setup comparison state observation
    func setupComparisonObservation() {
        // Observe images array changes to validate comparison selection
        $images
            .sink { [weak self] _ in
                self?.refreshComparisonPreviewIfNeeded()
            }
            .store(in: &cancellables)
        
        // Observe comparison selection changes
        $comparisonSelection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selection in
                guard let self else { return }
                if selection == nil {
                    self.comparisonPreview = .empty
                    self.comparisonPreviewTask?.cancel()
                    self.comparisonPreviewTask = nil
                    self.liveRenderDebounceWorkItem?.cancel()
                }
                // Note: Don't trigger refresh here - let ComparisonView do it after animation
            }
            .store(in: &cancellables)
        
        // Observe pipeline-affecting properties and trigger comparison refresh
        Publishers.CombineLatest4(
            $resizeMode,
            $selectedFormat,
            $compressionPercent,
            $resizeWidth
        )
        .dropFirst() // Skip initial value
        .sink { [weak self] _ in
            self?.scheduleComparisonPreviewRefresh()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest3(
            $flipV,
            $removeBackground,
            $removeMetadata
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.scheduleComparisonPreviewRefresh()
        }
        .store(in: &cancellables)
        
        $resizeHeight
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleComparisonPreviewRefresh()
            }
            .store(in: &cancellables)
    }
    // MARK: - Comparison Flow
    
    func presentComparison(for asset: ImageAsset) {
        comparisonSelection = ComparisonSelection(assetID: asset.id)
    }
    
    func dismissComparison() {
        comparisonSelection = nil
    }
    
    func navigateToNextImage() {
        guard let selection = comparisonSelection else { return }
        guard let currentIndex = images.firstIndex(where: { $0.id == selection.assetID }) else { return }
        let nextIndex = (currentIndex + 1) % images.count
        comparisonSelection = ComparisonSelection(assetID: images[nextIndex].id)
    }
    
    func navigateToPreviousImage() {
        guard let selection = comparisonSelection else { return }
        guard let currentIndex = images.firstIndex(where: { $0.id == selection.assetID }) else { return }
        let previousIndex = (currentIndex - 1 + images.count) % images.count
        comparisonSelection = ComparisonSelection(assetID: images[previousIndex].id)
    }
    
    func refreshComparisonPreviewIfNeeded() {
        guard let selection = comparisonSelection else { return }
        guard images.contains(where: { $0.id == selection.assetID }) else {
            comparisonSelection = nil
            return
        }
    }
    
    func refreshComparisonPreview() {
        guard let selection = comparisonSelection,
              let asset = images.first(where: { $0.id == selection.assetID }) else { return }
        
        // Calculate crop region immediately for consistency
        let cropRegion = calculateCropRegion(for: asset)
        
        // Immediately show thumbnail for instant feedback
        comparisonPreview = ComparisonPreviewState(
            originalImage: asset.thumbnail,
            processedImage: nil,
            isLoading: true,
            errorMessage: nil,
            cropRegion: cropRegion,
            originalSize: asset.originalPixelSize,
            processedSize: nil
        )
        
        comparisonPreviewTask?.cancel()
        comparisonPreviewTask = Task { [weak self] in
            await self?.loadComparisonPreview(for: asset)
        }
    }
    
    func scheduleComparisonPreviewRefresh() {
        guard comparisonSelection != nil else { return }
        liveRenderDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshComparisonPreview()
        }
        liveRenderDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
    
    // MARK: - Private
    
    private func loadComparisonPreview(for asset: ImageAsset) async {
        let assetID = asset.id
        
        // Calculate crop region
        let cropRegion = await MainActor.run { calculateCropRegion(for: asset) }
        
        // Load original image off main thread
        let original = await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: asset.originalURL)
        }.value
        
        let originalSize = original?.size
        
        // Check if this asset is still selected before updating
        guard await isStillSelected(assetID) else { return }
        
        await MainActor.run {
            comparisonPreview = ComparisonPreviewState(
                originalImage: original,
                processedImage: nil,
                isLoading: true,
                errorMessage: nil,
                cropRegion: cropRegion,
                originalSize: originalSize,
                processedSize: nil
            )
        }
        
        // Process image in background
        do {
            let pipeline = buildPipeline()
            let processed = try await Task.detached(priority: .userInitiated) {
                let temporaryURL = try pipeline.renderTemporaryURL(on: asset)
                return NSImage(contentsOf: temporaryURL)
            }.value
            
            let processedSize = processed?.size
            
            guard await isStillSelected(assetID) else { return }
            
            await MainActor.run {
                comparisonPreview = ComparisonPreviewState(
                    originalImage: original,
                    processedImage: processed,
                    isLoading: false,
                    errorMessage: nil,
                    cropRegion: cropRegion,
                    originalSize: originalSize,
                    processedSize: processedSize
                )
            }
        } catch {
            guard await isStillSelected(assetID) else { return }
            
            await MainActor.run {
                comparisonPreview = ComparisonPreviewState(
                    originalImage: original,
                    processedImage: nil,
                    isLoading: false,
                    errorMessage: error.localizedDescription,
                    cropRegion: cropRegion,
                    originalSize: originalSize,
                    processedSize: nil
                )
            }
        }
    }
    
    private func isStillSelected(_ assetID: UUID) async -> Bool {
        await MainActor.run { comparisonSelection?.assetID == assetID }
    }
    
    /// Calculate the normalized crop region (0-1 coordinates) on the original image
    func calculateCropRegion(for asset: ImageAsset) -> CGRect? {
        guard resizeMode == .crop,
              let targetWidth = Int(resizeWidth),
              let targetHeight = Int(resizeHeight),
              let originalSize = asset.originalPixelSize,
              originalSize.width > 0,
              originalSize.height > 0 else {
            return nil
        }
        
        let currentWidth = originalSize.width
        let currentHeight = originalSize.height
        let targetW = CGFloat(targetWidth)
        let targetH = CGFloat(targetHeight)
        
        // Calculate scale to COVER the target dimensions (matching CropOperation logic)
        let scaleX = targetW / currentWidth
        let scaleY = targetH / currentHeight
        let scale = max(scaleX, scaleY)
        
        // Size after scaling
        let scaledWidth = currentWidth * scale
        let scaledHeight = currentHeight * scale
        
        // Center crop position (in scaled space)
        let cropX = (scaledWidth - targetW) / 2
        let cropY = (scaledHeight - targetH) / 2
        
        // Convert back to original image space
        let originXInOriginal = cropX / scale
        let originYInOriginal = cropY / scale
        let widthInOriginal = targetW / scale
        let heightInOriginal = targetH / scale
        
        // Normalize to 0-1 range
        let normalizedRect = CGRect(
            x: originXInOriginal / currentWidth,
            y: originYInOriginal / currentHeight,
            width: widthInOriginal / currentWidth,
            height: heightInOriginal / currentHeight
        )
        
        return normalizedRect
    }
}

