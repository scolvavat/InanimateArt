import SwiftUI

struct Welcome: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                
                // prevents cramped layout on smaller phones
                
                VStack(spacing: 16) {

                    Spacer(minLength: 12)

                    Text("Inanimate Art")
                        .font(.custom("OpenDyslexic3", size: 34))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Image("morphed")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                    
    // keeps it from getting huge
                    
                        .cornerRadius(20)
                        .shadow(radius: 8)
                        .padding(.top, 6)
                        .padding(.bottom, 8)

                    Text("In some cultures/religions around the world some to all forms of art are considered taboo and must not contain living things (animal or human doesnt matter) due to them having a soul and we as people aren't able to create souls. This app is a tribute to all art forms and their beauty. It does so by preserving meaningful images—whether it’s a family member, a pet, or anything else—by transforming them into a mosaic art piece. This app brings art for all!")
                        .font(.custom("OpenDyslexic3", size: 14))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    NavigationLink {
                        WhyIA()
                    } label: {
                        Text("Continue")
                            .font(.custom("OpenDyslexic3", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
                
                // keeps it centered nicely
                
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
