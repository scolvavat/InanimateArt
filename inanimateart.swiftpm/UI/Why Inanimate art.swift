import SwiftUI

// general info

struct WhyIA: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This app takes art/photos that would be considered taboo and turns them into something more acceptable without generating new pixels.")
                        .font(.custom("OpenDyslexic3", size: 14))

                    Text("How does it work?")
                        .font(.custom("OpenDyslexic3", size: 18))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("It sorts your image into chunks and organizes them by brightness to match the target image, below is a picture of my dog and her transformation with the middle preset on the top!")
                        .font(.custom("OpenDyslexic3", size: 14))

                    HStack(alignment: .top, spacing: 16) {
                        if let ui1 = loadPlaygroundImage(named: "kirby") {
                            Image(uiImage: ui1)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                        }

                        if let ui2 = loadPlaygroundImage(named: "morphed") {
                            Image(uiImage: ui2)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Why inanimate art?")
                        .font(.custom("OpenDyslexic3", size: 16))
                }
            }

            .safeAreaInset(edge: .bottom) {
                NavigationLink("Continue") { ContentView() }
                    .font(.custom("OpenDyslexic3", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }
}
