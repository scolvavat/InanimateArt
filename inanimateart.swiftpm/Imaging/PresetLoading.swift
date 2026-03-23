import UIKit

// loads preset images in a way that works both in the app and in Playgrounds

// tries the asset catalog first, then falls back to bundle file lookups

func loadPlaygroundImage(named name: String, ext: String? = nil) -> UIImage? {
    
    // first try the normal asset lookup (and also the easy “name.ext” version)
    
    if ext == nil, let img = UIImage(named: name) { return img }
    if let ext, let img = UIImage(named: "\(name).\(ext)") { return img }
    
    // if that didn’t work, try grabbing it straight from the main bundle as a file
    
    if let ext,
       let url = Bundle.main.url(forResource: name, withExtension: ext),
       let data = try? Data(contentsOf: url),
       let img = UIImage(data: data) {
        return img
    }
    
    // last resort: scan every bundle/framework until we find it
    
    let bundles = Bundle.allBundles + Bundle.allFrameworks
    for b in bundles {
        if ext == nil, let img = UIImage(named: name, in: b, compatibleWith: nil) { return img }
        if let ext,
           let url = b.url(forResource: name, withExtension: ext),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
    }
    return nil
}
