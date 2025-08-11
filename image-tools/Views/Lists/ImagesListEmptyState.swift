import SwiftUI

struct ImagesListEmptyState: View {
    let onPaste: () -> Void
    let onPickFromFinder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Text(String(localized: "Drag or "))
                    Button(action: onPaste) {
                        Text(String(localized: "Paste  ")).underline()
                    }
                    .buttonStyle(.plain)
                    Text("`⌘+V`").monospaced(true)
                    Text(String(localized: " your images here."))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                HStack(spacing: 0) {
                    Text(String(localized: "Or select "))
                    Button(action: onPickFromFinder) {
                        Text(String(localized: "Folder")).underline()
                    }
                    .buttonStyle(.plain)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct ImagesListEmptyState_Previews: PreviewProvider {
    static var previews: some View {
        ImagesListEmptyState(
            onPaste: {},
            onPickFromFinder: {}
        )
        .frame(width: 700, height: 400)
        .padding()
    }
} 


