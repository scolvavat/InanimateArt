import SwiftUI
import MetalKit
import UIKit

// SwiftUI wrapper for MTKView

// keeps Metal + rendering out of ContentView and gives SwiftUI a clean API

struct MetalView: UIViewRepresentable {
    @Binding var isPlaying: Bool
    let sourceImage: UIImage
    let targetImage: UIImage
    let configToken: UUID
    let onRendererReady: (InanimateArtRenderer) -> Void
    let simSide: Int = 64
 
    // holds onto the renderer across SwiftUI updates
    
    // SwiftUI recreates views a lot, this stops random renderer resets

    final class Coordinator {
        var renderer: InanimateArtRenderer?
        var lastToken: UUID = UUID()
        var didSendRenderer = false
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
      
        // create the renderer once and attach it to the MTKView
        
        // MTKView calls draw(in:) every frame
        
        let renderer = InanimateArtRenderer(mtkView: view)
        context.coordinator.renderer = renderer
        context.coordinator.lastToken = configToken
        view.delegate = renderer
        
        renderer?.configure(source: sourceImage, target: targetImage, simSide: simSide)
        renderer?.setPlaying(isPlaying)
      
        // send the renderer back to SwiftUI once
        
        if let r = renderer, context.coordinator.didSendRenderer == false {
            context.coordinator.didSendRenderer = true
            DispatchQueue.main.async { onRendererReady(r) }
        }
        
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.setPlaying(isPlaying)
        
        // configToken is the “rebuild now” signal
        
        // if it changes, reconfigure with the new images

        if context.coordinator.lastToken != configToken {
            context.coordinator.lastToken = configToken
            renderer.configure(source: sourceImage, target: targetImage, simSide: simSide)
            renderer.setPlaying(isPlaying)
        }
        
        // safety: if the callback didn’t fire yet, send it here once

        if context.coordinator.didSendRenderer == false {
            context.coordinator.didSendRenderer = true
            DispatchQueue.main.async { onRendererReady(renderer) }
        }
    }
}
