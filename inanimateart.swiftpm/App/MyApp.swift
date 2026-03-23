import SwiftUI

@main
struct MyApp: App {

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            Welcome()   
        }
    }
}
