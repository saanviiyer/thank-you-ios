import UIKit

enum ImageProcessor {
    static func compressedJPEG(
        from data: Data,
        maxDimension: CGFloat,
        maxBytes: Int
    ) -> Data? {
        guard let source = UIImage(data: data), maxDimension > 0, maxBytes > 0 else { return nil }
        let longest = max(source.size.width, source.size.height)
        let scale = min(1, maxDimension / max(longest, 1))
        let target = CGSize(
            width: max(1, floor(source.size.width * scale)),
            height: max(1, floor(source.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        for quality in stride(from: 0.85, through: 0.35, by: -0.1) {
            if let output = rendered.jpegData(compressionQuality: quality), output.count <= maxBytes {
                return output
            }
        }
        return nil
    }
}
