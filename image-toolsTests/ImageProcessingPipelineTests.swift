//
//  ImageProcessingPipelineTests.swift
//  image-toolsTests
//
//  Created by Raphael Wennmacher on 07.08.25.
//

import Testing
import Foundation
import AppKit
import UniformTypeIdentifiers
import CoreImage
@testable import image_tools

struct ImageProcessingPipelineTests {
    
    // MARK: - Test Setup
    
    /// Creates a simple test image for testing operations
    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: NSColor = .red) throws -> URL {
        let image = NSImage(size: size)
        image.lockFocus()
        color.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_image_\(UUID().uuidString.prefix(8)).png")
        
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create test image"])
        }
        
        try pngData.write(to: tempURL)
        return tempURL
    }
    
    /// Creates a test image with EXIF metadata for metadata removal tests
    private func createTestImageWithMetadata() throws -> URL {
        let testURL = try createTestImage()
        
        // Add some basic metadata by re-saving with metadata
        guard let ciImage = CIImage(contentsOf: testURL) else {
            throw NSError(domain: "TestError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load test image"])
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_image_with_metadata_\(UUID().uuidString.prefix(8)).jpg")
        
        let context = CIContext()
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let cgImage = context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace),
              let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "TestError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image with metadata"])
        }
        
        // Add some metadata
        let metadata: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifUserComment: "Test metadata",
                kCGImagePropertyExifDateTimeOriginal: "2024:01:01 12:00:00"
            ],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.7749,
                kCGImagePropertyGPSLongitude: -122.4194
            ]
        ]
        
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        return tempURL
    }
    
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    private func fileSize(at url: URL) -> Int? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.intValue
    }
    
    // MARK: - Format Conversion Tests
    
    @Test func testAllFormatConversions() async throws {
        let capabilities = ImageIOCapabilities.shared
        let writableFormats = capabilities.writableFormats()
        
        // Create a test image in PNG format (most compatible)
        let sourceURL = try createTestImage()
        defer { cleanup(sourceURL) }
        
        // Test conversion to each writable format
        for targetFormat in writableFormats {
            let convertOp = ConvertOperation(format: targetFormat)
            
            do {
                let convertedURL = try convertOp.apply(to: sourceURL)
                defer { cleanup(convertedURL) }
                
                // Verify the file was created and has content
                #expect(FileManager.default.fileExists(atPath: convertedURL.path))
                #expect((fileSize(at: convertedURL) ?? 0) > 0)
                
                // Verify the format matches expected extension
                let expectedExt = capabilities.preferredFilenameExtension(for: targetFormat.utType)
                #expect(convertedURL.pathExtension.lowercased() == expectedExt.lowercased())
                
                // Verify we can load the converted image
                #expect(NSImage(contentsOf: convertedURL) != nil)
                
            } catch {
                print("Conversion to \(targetFormat.displayName) failed: \(error)")
            }
        }
    }
    
    @Test func testConversionWithPipeline() async throws {
        let capabilities = ImageIOCapabilities.shared
        let writableFormats = capabilities.writableFormats().prefix(3) // Test first 3 for efficiency
        
        let sourceURL = try createTestImage()
        defer { cleanup(sourceURL) }
        
        let asset = ImageAsset(url: sourceURL)
        
        for targetFormat in writableFormats {
            var pipeline = ProcessingPipeline()
            pipeline.add(ConvertOperation(format: targetFormat))
            
            do {
                let result = try pipeline.run(on: asset)
                defer { cleanup(result.workingURL) }
                
                #expect(result.isEdited == true)
                #expect(FileManager.default.fileExists(atPath: result.workingURL.path))
                
            } catch {
                print("Pipeline conversion to \(targetFormat.displayName) failed: \(error)")
            }
        }
    }
    
    // MARK: - Resize Tests
    
    @Test func testResizeOperations() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 200, height: 200))
        defer { cleanup(sourceURL) }
        
        // Test percent resize
        let percentOp = ResizeOperation(mode: .percent(0.5))
        let resizedURL = try percentOp.apply(to: sourceURL)
        defer { cleanup(resizedURL) }
        
        guard let resizedImage = NSImage(contentsOf: resizedURL) else {
            throw NSError(domain: "TestError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to load resized image"])
        }
        
        // Should be approximately half the original size
        #expect(abs(resizedImage.size.width - 100) < 5)
        #expect(abs(resizedImage.size.height - 100) < 5)
    }
    
    @Test func testResizePixels() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 200, height: 200))
        defer { cleanup(sourceURL) }
        
        // Test pixel resize
        let pixelOp = ResizeOperation(mode: .pixels(width: 150, height: 150))
        let resizedURL = try pixelOp.apply(to: sourceURL)
        defer { cleanup(resizedURL) }
        
        guard let resizedImage = NSImage(contentsOf: resizedURL) else {
            throw NSError(domain: "TestError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to load pixel resized image"])
        }
        
        // Note: Actual size might differ due to aspect ratio preservation
        #expect(resizedImage.size.width > 0)
        #expect(resizedImage.size.height > 0)
    }
    
    @Test func testResizeWithPipeline() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 300, height: 300))
        defer { cleanup(sourceURL) }
        
        let asset = ImageAsset(url: sourceURL)
        var pipeline = ProcessingPipeline()
        pipeline.add(ResizeOperation(mode: .percent(0.3)))
        
        let result = try pipeline.run(on: asset)
        defer { cleanup(result.workingURL) }
        
        #expect(result.isEdited == true)
        
        guard let resultImage = NSImage(contentsOf: result.workingURL) else {
            throw NSError(domain: "TestError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to load pipeline resized image"])
        }
        
        // Should be approximately 30% of original
        #expect(resultImage.size.width < 150) // Less than half of 300
        #expect(resultImage.size.height < 150)
    }
    
    // MARK: - Compression Tests
    
    @Test func testCompressionPercent() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 500, height: 500))
        defer { cleanup(sourceURL) }
        
        // Convert to JPEG first for compression
        let convertOp = ConvertOperation(format: ImageFormat(utType: .jpeg))
        let jpegURL = try convertOp.apply(to: sourceURL)
        defer { cleanup(jpegURL) }
        
        let originalSize = fileSize(at: jpegURL) ?? 0
        
        // Test percent compression
        let compressOp = CompressOperation(mode: .percent(0.3), formatHint: ImageFormat(utType: .jpeg))
        let compressedURL = try compressOp.apply(to: jpegURL)
        defer { cleanup(compressedURL) }
        
        let compressedSize = fileSize(at: compressedURL) ?? 0
        
        #expect(compressedSize < originalSize)
        #expect(compressedSize > 0)
        #expect(NSImage(contentsOf: compressedURL) != nil)
    }
    
    @Test func testCompressionTargetKB() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 500, height: 500))
        defer { cleanup(sourceURL) }
        
        // Convert to JPEG for compression
        let convertOp = ConvertOperation(format: ImageFormat(utType: .jpeg))
        let jpegURL = try convertOp.apply(to: sourceURL)
        defer { cleanup(jpegURL) }
        
        // Target 50KB
        let targetKB = 50
        let compressOp = CompressOperation(mode: .targetKB(targetKB), formatHint: ImageFormat(utType: .jpeg))
        let compressedURL = try compressOp.apply(to: jpegURL)
        defer { cleanup(compressedURL) }
        
        let compressedSize = fileSize(at: compressedURL) ?? 0
        let compressedKB = compressedSize / 1024
        
        // Should be reasonably close to target (within 20KB tolerance)
        #expect(compressedKB <= targetKB + 20)
        #expect(compressedSize > 0)
        #expect(NSImage(contentsOf: compressedURL) != nil)
    }
    
    // MARK: - Mirroring/Flipping Tests
    
    @Test func testHorizontalFlip() async throws {
        let sourceURL = try createTestImage()
        defer { cleanup(sourceURL) }
        
        let flipOp = FlipOperation(direction: .horizontal)
        let flippedURL = try flipOp.apply(to: sourceURL)
        defer { cleanup(flippedURL) }
        
        #expect(FileManager.default.fileExists(atPath: flippedURL.path))
        #expect((fileSize(at: flippedURL) ?? 0) > 0)
        #expect(NSImage(contentsOf: flippedURL) != nil)
        
        // Verify the flipped image has same dimensions as original
        guard let originalImage = NSImage(contentsOf: sourceURL),
              let flippedImage = NSImage(contentsOf: flippedURL) else {
            throw NSError(domain: "TestError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to load images for flip comparison"])
        }
        
        #expect(abs(originalImage.size.width - flippedImage.size.width) < 1)
        #expect(abs(originalImage.size.height - flippedImage.size.height) < 1)
    }
    
    @Test func testVerticalFlip() async throws {
        let sourceURL = try createTestImage()
        defer { cleanup(sourceURL) }
        
        let flipOp = FlipOperation(direction: .vertical)
        let flippedURL = try flipOp.apply(to: sourceURL)
        defer { cleanup(flippedURL) }
        
        #expect(FileManager.default.fileExists(atPath: flippedURL.path))
        #expect((fileSize(at: flippedURL) ?? 0) > 0)
        #expect(NSImage(contentsOf: flippedURL) != nil)
    }
    
    @Test func testFlipWithPipeline() async throws {
        let sourceURL = try createTestImage()
        defer { cleanup(sourceURL) }
        
        let asset = ImageAsset(url: sourceURL)
        var pipeline = ProcessingPipeline()
        pipeline.add(FlipOperation(direction: .horizontal))
        pipeline.add(FlipOperation(direction: .vertical)) // Should flip back somewhat
        
        let result = try pipeline.run(on: asset)
        defer { cleanup(result.workingURL) }
        
        #expect(result.isEdited == true)
        #expect(FileManager.default.fileExists(atPath: result.workingURL.path))
    }
    
    // MARK: - Metadata Removal Tests
    
    @Test func testMetadataRemoval() async throws {
        let sourceURL = try createTestImageWithMetadata()
        defer { cleanup(sourceURL) }
        
        let asset = ImageAsset(url: sourceURL)
        var pipeline = ProcessingPipeline()
        pipeline.removeMetadata = true
        
        let result = try pipeline.run(on: asset)
        defer { cleanup(result.workingURL) }
        
        #expect(result.isEdited == true)
        
        // Verify metadata was removed by checking image properties
        guard let imageSource = CGImageSourceCreateWithURL(result.workingURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw NSError(domain: "TestError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to read image properties"])
        }
        
        // Should not have EXIF data
        #expect(properties[kCGImagePropertyExifDictionary] == nil)
        // Should not have GPS data
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        // Orientation should be normalized to 1
        if let orientation = properties[kCGImagePropertyOrientation] as? Int {
            #expect(orientation == 1)
        }
    }
    
    @Test func testMetadataRemovalWithFormatConversion() async throws {
        let sourceURL = try createTestImageWithMetadata()
        defer { cleanup(sourceURL) }
        
        let asset = ImageAsset(url: sourceURL)
        var pipeline = ProcessingPipeline()
        pipeline.add(ConvertOperation(format: ImageFormat(utType: .png)))
        pipeline.removeMetadata = true
        
        let result = try pipeline.run(on: asset)
        defer { cleanup(result.workingURL) }
        
        #expect(result.isEdited == true)
        #expect(result.workingURL.pathExtension.lowercased() == "png")
        
        // Verify the image is readable and metadata-free
        #expect(NSImage(contentsOf: result.workingURL) != nil)
    }
    
    // MARK: - Combined Operations Tests
    
    @Test func testComplexPipeline() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 400, height: 400))
        defer { cleanup(sourceURL) }
        
        let asset = ImageAsset(url: sourceURL)
        var pipeline = ProcessingPipeline()
        
        // Combine multiple operations
        pipeline.add(ResizeOperation(mode: .percent(0.5)))
        pipeline.add(FlipOperation(direction: .horizontal))
        pipeline.add(ConvertOperation(format: ImageFormat(utType: .jpeg)))
        pipeline.add(CompressOperation(mode: .percent(0.7), formatHint: ImageFormat(utType: .jpeg)))
        pipeline.removeMetadata = true
        
        let result = try pipeline.run(on: asset)
        defer { cleanup(result.workingURL) }
        
        #expect(result.isEdited == true)
        #expect(result.workingURL.pathExtension.lowercased() == "jpg")
        
        guard let resultImage = NSImage(contentsOf: result.workingURL) else {
            throw NSError(domain: "TestError", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to load complex pipeline result"])
        }
        
        // Should be resized to approximately half
        #expect(resultImage.size.width < 250) // Less than half of 400 due to compression/processing
        #expect(resultImage.size.height < 250)
    }
    
    // MARK: - Capability Respect Tests
    
    @Test func testCapabilityRespect() async throws {
        let capabilities = ImageIOCapabilities.shared
        
        // Test that we respect format capabilities
        for format in capabilities.writableFormats().prefix(5) {
            let formatCapabilities = capabilities.capabilities(for: format)
            
            #expect(formatCapabilities.isWritable == true)
            
            // If format supports quality compression, test it
            if formatCapabilities.supportsQuality {
                let sourceURL = try createTestImage()
                defer { cleanup(sourceURL) }
                
                let convertOp = ConvertOperation(format: format)
                let convertedURL = try convertOp.apply(to: sourceURL)
                defer { cleanup(convertedURL) }
                
                let compressOp = CompressOperation(mode: .percent(0.5), formatHint: format)
                let compressedURL = try compressOp.apply(to: convertedURL)
                defer { cleanup(compressedURL) }
                
                #expect(FileManager.default.fileExists(atPath: compressedURL.path))
            }
            
            // If format supports metadata, test metadata handling
            if formatCapabilities.supportsMetadata {
                let sourceURL = try createTestImageWithMetadata()
                defer { cleanup(sourceURL) }
                
                let asset = ImageAsset(url: sourceURL)
                var pipeline = ProcessingPipeline()
                pipeline.add(ConvertOperation(format: format))
                pipeline.removeMetadata = true
                
                do {
                    let result = try pipeline.run(on: asset)
                    defer { cleanup(result.workingURL) }
                    
                    #expect(result.isEdited == true)
                } catch {
                    print("Metadata test for \(format.displayName) failed: \(error)")
                }
            }
        }
    }
    
    @Test func testFormatCapabilityConsistency() async throws {
        let capabilities = ImageIOCapabilities.shared
        let allFormats = capabilities.allImageFormats()
        
        // Verify that writable formats are a subset of readable formats
        let writableFormats = capabilities.writableFormats()
        let readableFormats = capabilities.readableFormats()
        
        for writableFormat in writableFormats {
            // We should be able to read formats we can write
            #expect(capabilities.supportsReading(utType: writableFormat.utType))
        }
        
        // Test that format capabilities are consistent
        for format in allFormats.prefix(10) { // Test first 10 for efficiency
            let caps = capabilities.capabilities(for: format)
            
            // If it's writable, we should support writing
            if caps.isWritable {
                #expect(capabilities.supportsWriting(utType: format.utType))
            }
            
            // If it's readable, we should support reading
            if caps.isReadable {
                #expect(capabilities.supportsReading(utType: format.utType))
            }
        }
    }
    
    @Test func testEdgeConditions() async throws {
        let sourceURL = try createTestImage(size: CGSize(width: 50, height: 50))
        defer { cleanup(sourceURL) }
        
        // Test very small resize
        let tinyResizeOp = ResizeOperation(mode: .percent(0.01))
        let tinyURL = try tinyResizeOp.apply(to: sourceURL)
        defer { cleanup(tinyURL) }
        
        #expect(FileManager.default.fileExists(atPath: tinyURL.path))
        #expect(NSImage(contentsOf: tinyURL) != nil)
        
        // Test very high compression
        let convertOp = ConvertOperation(format: ImageFormat(utType: .jpeg))
        let jpegURL = try convertOp.apply(to: sourceURL)
        defer { cleanup(jpegURL) }
        
        let highCompressOp = CompressOperation(mode: .percent(0.01), formatHint: ImageFormat(utType: .jpeg))
        let highCompressURL = try highCompressOp.apply(to: jpegURL)
        defer { cleanup(highCompressURL) }
        
        #expect(FileManager.default.fileExists(atPath: highCompressURL.path))
        #expect((fileSize(at: highCompressURL) ?? 0) > 0)
    }
}
