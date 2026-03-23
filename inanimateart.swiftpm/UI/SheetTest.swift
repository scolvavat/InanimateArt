import SwiftUI

// Dedicated instructions page with instructions

// Presented from ContentView via a question mark button

struct SheetTest: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to use")
                    .font(.custom("OpenDyslexic3", size: 18))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("1) Tap 'Gallery' at the bottom to pick a photo (or 'Camera' for camera input) to upload and have transform into a mosaic.")
                    .font(.custom("OpenDyslexic3", size: 16))
                Text("2) Pick one of the 6 mosaics, or tap 'Custom Target' if you have your own template")
                    .font(.custom("OpenDyslexic3", size: 16))
                Text("3) Watch it morph. TWICE.")
                    .font(.custom("OpenDyslexic3", size: 16))
                Text("4) Tap 'Add to gallery' at the end to have a copy of the final image!")
                    .font(.custom("OpenDyslexic3", size: 16))
                Text("")
                Text("Notes: may take 10 seconds to morph. It's also recommended to use this in portrait not landscape.")
                    .font(.custom("OpenDyslexic3", size: 16))

                Button("Done") { dismiss() }
                    .font(.custom("OpenDyslexic3", size: 18))
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
    }
}
