import AppKit
import UniformTypeIdentifiers

enum ClipboardService {
    
    /// Copy an image from a URL to the clipboard
    static func copyImage(from url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var objects: [NSPasteboardWriting] = []
        if let image = NSImage(contentsOf: url) {
            objects.append(image)
        }
        objects.append(url as NSURL)
        pasteboard.writeObjects(objects)
    }
    
    /// Copy encoded image data to the clipboard with proper UTI
    static func copyEncodedImage(data: Data, uti: UTType) {
        let pasteboard = NSPasteboard.general
        
        // Create temporary file for apps that prefer file-based paste
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: uti)
        let filename = "copy-\(String(UUID().uuidString.prefix(8))).\(ext)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Continue with in-memory representation if file writing fails
        }
        
        // Create pasteboard item with raw data
        let item = NSPasteboardItem()
        let imageType = NSPasteboard.PasteboardType(uti.identifier)
        item.setData(data, forType: imageType)
        
        // Write both file URL and raw data
        pasteboard.clearContents()
        _ = pasteboard.writeObjects([fileURL as NSURL, item])
    }
    
    /// Reveal file in Finder
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

