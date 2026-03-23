import CoreText
import Foundation

// Registers bundled custom fonts at app launch

func registerCustomFonts() {
    registerFontFile("OD3", ext: "ttf")
}

private func registerFontFile(_ name: String, ext: String) {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
        print("Could not find \(name).\(ext) in Bundle.main")
        return
    }

    var error: Unmanaged<CFError>?
    let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

    if ok {
        print("Registered \(name).\(ext)")
    } else {
       
        // Common if it’s already registered; still fine.
        
        print("Font register issue for \(name).\(ext):", error?.takeRetainedValue() as Any)
    }
}
