import SwiftUI
import PhotosUI
import UIKit
import Photos

// main screen and functions

// pick image source (camera or gallery)

// choose a custom or preset image

// runs the morph renderer in real time

// saves to camera roll

struct ContentView: View {
    
    // source pic
    
    @State private var sourcePickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage? = nil
    
    // target pic
    
    @State private var selectedPresetIndex: Int = 0
    @State private var customTargetPickerItem: PhotosPickerItem?
    @State private var customTargetImage: UIImage? = nil
    
    // camera sheet
    
    @State private var showSourceCamera: Bool = false
    @State private var showHelp: Bool = false
    
    // render control
    
    @State private var isPlaying: Bool = true
    
    //don’t change this token (forces MetalView to re-configure the renderer)
    
    @State private var configToken: UUID = UUID()
    
    //calls back to the renderer so I can snapshot
    
    @State private var rendererRef: InanimateArtRenderer? = nil
    
    // if trying to save before it loads, wait
    
    @State private var pendingSave: Bool = false
    
    // error alert
    
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // preset pictures bundled
    
    private let presetNames: [String] = ["preset1","preset2","preset3","preset4","preset5","preset6"]
    private var gridColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 6), count: 3) }
    
    private func clamp(_ x: Int, _ lo: Int, _ hi: Int) -> Int {
        min(max(x, lo), hi)
    }
    
    private func presetUIImage(at index: Int) -> UIImage {
        
        // Clamp index so i never crash if state gets out of range
        
        let name = presetNames[clamp(index, 0, presetNames.count - 1)]
        
        //try loading from bundled images
        
        return loadPlaygroundImage(named: name) ??
        loadPlaygroundImage(named: name, ext: "png") ??
        makePlaceholder(size: 256)
    }
    
    private var activeTargetImage: UIImage {
        
        // if you picked a custom target, that’s the one we use. otherwise it’s the preset you tapped
        
        if let customTargetImage { return customTargetImage }
        return presetUIImage(at: selectedPresetIndex)
    }
    
    private var activeSourceImage: UIImage {
        
        // if you haven’t picked a source yet, I just show a placeholder so nothing breaks
        
        sourceImage ?? makePlaceholder(size: 512)
    }
    
    private func rebuildRenderer() {
        
        // Bump the token so MetalView reconfigures the renderer with new images
        
        configToken = UUID()
        isPlaying = true
    }
    
    private func requestPhotoAddAuthIfNeeded(_ completion: @escaping (Bool) -> Void) {
        
        // I request "addOnly" permission so the app can save without needing full library access
        
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            switch status {
            case .authorized, .limited:
                completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    DispatchQueue.main.async {
                        completion(newStatus == .authorized || newStatus == .limited)
                    }
                }
            default:
                completion(false)
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    DispatchQueue.main.async { completion(newStatus == .authorized) }
                }
            default:
                completion(false)
            }
        }
    }
    
    private func performSave(with renderer: InanimateArtRenderer) {
        
        // Pull the current rendered frame from the offscreen capture texture
        
        guard let img = renderer.snapshot512() else {
            alertMessage = "Could not capture the current frame."
            showAlert = true
            return
        }
        
        // Metal + UIKit don’t agree on “up”, so I flip it so it saves the right way
        
        let corrected = img.verticallyFlipped()
        
        // ask for the smallest Photos permission we need, then save it to camera roll
        
        requestPhotoAddAuthIfNeeded { allowed in
            guard allowed else {
                alertMessage = "Photo permission not granted. Enable Photos access to save."
                showAlert = true
                return
            }
            UIImageWriteToSavedPhotosAlbum(corrected, nil, nil, nil)
            alertMessage = "Saved to Photos."
            showAlert = true
        }
    }
    
    private func saveTapped() {
        
        // if the renderer is already ready, save right away
        
        // if it’s not ready yet, queue the save and rebuild so it can grab a frame
        
        if let r = rendererRef {
            performSave(with: r)
        } else {
            pendingSave = true
            configToken = UUID()
        }
    }
    
    var body: some View {
        Group {
#if os(macOS) || targetEnvironment(macCatalyst)
            ScrollView {
                VStack(spacing: 12) {
                    contentBody
                }
            }
#else
            VStack(spacing: 12) {
                contentBody
            }
#endif
        }
        .onAppear { showHelp = true }
        .navigationBarBackButtonHidden(true)
#if os(macOS) || targetEnvironment(macCatalyst)
        .frame(minWidth: 600, minHeight: 800)
#endif
        .alert("Inanimate Art", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showSourceCamera) {
            CameraPicker { img in
                DispatchQueue.main.async {
                    self.sourceImage = img
                    self.rebuildRenderer()
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            SheetTest()
        }
    }
    
    private var contentBody: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Inanimate Art")
                    .font(.custom("OpenDyslexic3", size: 18))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // preset grid (tap one to use it)
            
#if os(macOS) || targetEnvironment(macCatalyst)
            
            GeometryReader { geo in
                
                // catalyst likes to lie about LazyVGrid height when each cell uses GeometryReader so i compute the square size once, then make fixed-size grid items
                
                let gridWidth = min(geo.size.width, 720)
                let cellSide = (gridWidth - (6 * 2)) / 3
                let columns = Array(repeating: GridItem(.fixed(cellSide), spacing: 6), count: 3)
                
                HStack {
                    Spacer(minLength: 0)
                    
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(presetNames.indices, id: \.self) { i in
                            let img = presetUIImage(at: i)
                            
                            Button {
                                selectedPresetIndex = i
                                customTargetImage = nil
                                rebuildRenderer()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                    
                                    // keeps the thumbnails from stretching into weird shapes on different screens
                                    
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: cellSide - 12, height: cellSide - 12)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                                .frame(width: cellSide, height: cellSide)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary, lineWidth: 2)
                                )
                                .overlay(
                                    Group {
                                        if customTargetImage == nil && selectedPresetIndex == i {
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.blue, lineWidth: 3)
                                        }
                                    }
                                )
                                .contentShape(Rectangle())
                            }
                            .padding(2)
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: gridWidth, alignment: .center)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // 2 rows of squares + 1 spacing gap between them
            
            .frame(height: (2 * ((720 - (6 * 2)) / 3)) + 6)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .center)
            
#else
            
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(presetNames.indices, id: \.self) { i in
                    let img = presetUIImage(at: i)
                    Button {
                        selectedPresetIndex = i
                        customTargetImage = nil
                        rebuildRenderer()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            
                            // keeps the thumbnails from stretching into weird shapes on different screens
                            
                            GeometryReader { geo in
                                
                                // force a square by using the width as the height
                                
                                let side = geo.size.width - 12
                                
                                // minus a little bit for padding so it actually fits
                                
                                VStack {
                                    
                                    // using a VStack just to keep the square centered
                                    
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: side, height: side)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(6)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary, lineWidth: 2)
                        )
                        .overlay(
                            Group {
                                if customTargetImage == nil && selectedPresetIndex == i {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.blue, lineWidth: 3)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                    }
                    .padding(2)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .center)
            
#endif
            
            // controls for picking a custom target, or switching back to presets
            
            HStack(spacing: 12) {
                PhotosPicker(selection: $customTargetPickerItem, matching: .images) {
                    Text("Custom Target")
                        .font(.custom("OpenDyslexic3", size: 16))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.purple.opacity(0.15))
                        .cornerRadius(10)
                }
                .onChange(of: customTargetPickerItem) {
                    guard let newItem = customTargetPickerItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run {
                                self.customTargetImage = img
                                self.rebuildRenderer()
                            }
                        }
                    }
                }
                
                if customTargetImage != nil {
                    Button("Use Presets") {
                        customTargetImage = nil
                        rebuildRenderer()
                    }
                    .font(.custom("OpenDyslexic3", size: 16))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(.gray.opacity(0.15))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            // Metal view doing the actual rendering
            
            MetalView(
                isPlaying: $isPlaying,
                sourceImage: activeSourceImage,
                targetImage: activeTargetImage,
                configToken: configToken,
                onRendererReady: { r in
                    
                    // save a reference to the renderer so i can snapshot later
                    
                    self.rendererRef = r
                    
                    // if you tapped save too early, run it now that the renderer finally exists
                    
                    if self.pendingSave {
                        self.pendingSave = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.performSave(with: r)
                        }
                    }
                }
            )
            .aspectRatio(1, contentMode: .fit)
#if os(macOS) || targetEnvironment(macCatalyst)
            .frame(maxWidth: 520)
#endif
            .frame(maxWidth: .infinity, alignment: .center)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal)
            
            // bottom buttons: gallery, camera, and save
            
            HStack(spacing: 12) {
                PhotosPicker(selection: $sourcePickerItem, matching: .images) {
                    Text("Gallery")
                        .font(.custom("OpenDyslexic3", size: 16))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.blue.opacity(0.15))
                        .cornerRadius(10)
                }
                .onChange(of: sourcePickerItem) {
                    guard let newItem = sourcePickerItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run {
                                self.sourceImage = img
                                self.rebuildRenderer()
                            }
                        }
                    }
                }
                
                Button {
                    
                    // quick check so i don’t open camera on a device that doesn’t have one
                    
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        alertMessage = "Camera not available on this device."
                        showAlert = true
                        return
                    }
                    showSourceCamera = true
                } label: {
                    Text("Camera")
                        .font(.custom("OpenDyslexic3", size: 16))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(.blue.opacity(0.15))
                .cornerRadius(10)
                
                Button {
                    saveTapped()
                } label: {
                    Text("Add to Camera Roll")
                        .font(.custom("OpenDyslexic3", size: 16))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(.green.opacity(0.15))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

private extension UIImage {
    
    // for some reason it saves upside down sometimes, so this flips it back to normal (its now 90 clockwise and Idk why I give up at this point lol)
    
    func verticallyFlipped() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        
        // keep transparency if the image has it
        
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: self.size, format: format)
        return renderer.image { ctx in
            let context = ctx.cgContext
            
            // flip the drawing context vertically so the image comes out right
            
            context.translateBy(x: 0, y: self.size.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(origin: .zero, size: self.size))
        }
    }
}
