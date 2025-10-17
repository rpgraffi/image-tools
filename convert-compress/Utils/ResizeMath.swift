import Foundation
import CoreGraphics

enum ResizeInput {
    case percent(Double)
    case pixels(width: Int?, height: Int?)
}

struct ResizeMath {
    static func targetSize(for original: CGSize, input: ResizeInput, noUpscale: Bool) -> CGSize {
        guard original.width > 0, original.height > 0 else { return CGSize(width: 0, height: 0) }

        switch input {
        case .percent(let p):
            let minScale = 0.01
            let unclamped = max(p, minScale)
            let scale = noUpscale ? min(unclamped, 1.0) : unclamped
            let w = max(1, (original.width * scale).rounded())
            let h = max(1, (original.height * scale).rounded())
            return CGSize(width: w, height: h)

        case .pixels(let wOpt, let hOpt):
            if let w = wOpt, hOpt == nil {
                let ratio = original.height / original.width
                let targetW = CGFloat(w)
                let cappedW = noUpscale ? min(targetW, original.width) : targetW
                let h = max(1, (cappedW * ratio).rounded())
                let finalW = max(1, cappedW.rounded())
                return CGSize(width: finalW, height: h)
            } else if let h = hOpt, wOpt == nil {
                let ratio = original.width / original.height
                let targetH = CGFloat(h)
                let cappedH = noUpscale ? min(targetH, original.height) : targetH
                let w = max(1, (cappedH * ratio).rounded())
                let finalH = max(1, cappedH.rounded())
                return CGSize(width: w, height: finalH)
            } else {
                var w = CGFloat(wOpt ?? Int(original.width))
                var h = CGFloat(hOpt ?? Int(original.height))
                if noUpscale {
                    w = min(w, original.width)
                    h = min(h, original.height)
                }
                return CGSize(width: max(1, w.rounded()), height: max(1, h.rounded()))
            }
        }
    }
}


