import UIKit

// placeholder image for when you haven’t picked anything yet

// keeps stuff from being nil, and makes it obvious the app is alive even before you choose a pic

func makePlaceholder(size: Int) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { ctx in
        let cg = ctx.cgContext
        
        // lay down a solid base so we’re not drawing on “nothing”
        
        cg.setFillColor(UIColor.black.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
        
        // draw a quick little wave pattern so it looks intentional and not just a blank box
        
        for y in 0..<size {
            for x in 0..<size {
                let t = Float(x) / Float(max(1, size - 1))
                let u = Float(y) / Float(max(1, size - 1))
                let v = 0.5 + 0.5 * sin((t * 8 + u * 6) * .pi)
                cg.setFillColor(UIColor(white: CGFloat(v), alpha: 1).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }
}
