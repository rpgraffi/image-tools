import Foundation

// MARK: - Byte Formatting

extension Int {
    func formattedBytes() -> String {
        formatBytes(self)
    }
}

func formatBytes(_ bytes: Int) -> String {
    let kb = 1024.0
    let mb = kb * 1024.0
    let b = Double(bytes)
    if b >= mb { return String(format: "%.2f MB", b/mb) }
    if b >= kb { return String(format: "%.0f KB", b/kb) }
    return "\(bytes) B"
}

