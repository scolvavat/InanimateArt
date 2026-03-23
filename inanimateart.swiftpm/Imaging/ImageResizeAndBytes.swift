import UIKit
import CoreGraphics

// Image prep helpers.

// i prep images here before anything else touches them

// i resize everything to a fixed square and turn it into RGBA8 bytes

// this keeps the sim consistent and way easier to reason about

func cgImageRGBA8(from image: UIImage, size: Int) -> CGImage? {
    
    // lock the size + scale so nothing “retina” randomly changes the math
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    
    // crop/resize into the exact square sim size (like 64x64)
    
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
    let resized = renderer.image { _ in
        image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    
    guard let cg = resized.cgImage else { return nil }
    
    // draw into a clean RGBA8 context so i control channel order + alpha
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = 4 * size
    
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

func bytesRGBA8(from cgImage: CGImage, size: Int) -> [UInt8] {
    
    // dumps the raw RGBA8 bytes into one flat array
    
    // index math: (y * size + x) * 4 + channel
    
    let bytesPerRow = 4 * size
    var data = [UInt8](repeating: 0, count: size * size * 4)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    data.withUnsafeMutableBytes { raw in
        if let ctx = CGContext(
            data: raw.baseAddress,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }
    return data
}

func luminance01(r: UInt8, g: UInt8, b: UInt8) -> Float {
    
    // quick brightness estimate (0..1)
    
    // i sort pixels by brightness before sending them out
    
    let rf = Float(r) / 255.0
    let gf = Float(g) / 255.0
    let bf = Float(b) / 255.0
    return 0.2126 * rf + 0.7152 * gf + 0.0722 * bf
}
