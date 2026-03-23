import Metal
import MetalKit
import UIKit

// Swift-side buffer layout for seeds.

// has to match the Metal Seed struct exactly or it’ll break

struct MetalSeed {
    var x: Float
    var y: Float
    var ox: Float
    var oy: Float
}

// MTKView delegate that runs the whole pipeline

// builds the compute pipeline (kernel is embedded as a string)

// steps the CPU sim each frame

// uploads seed positions to the GPU

// runs the compute kernel into an offscreen texture

// then draws that texture fullscreen to the screen

final class InanimateArtRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let presentPipeline: MTLRenderPipelineState
    
    private var seedBuffer: MTLBuffer?
    private var seedCount: Int = 0
    private var simSide: Int = 0
    private var simulation: InanimateArtSimulation?
    private var sourceTexture: MTLTexture?
    
    // offscreen render target so i can snapshot the exact frame i’m showing
    
    // IMPORTANT: this is fixed at 512x512 again for efficiency,
    
    // but unlike the broken versions, it still gets drawn fullscreen on screen
    
    private var captureTexture: MTLTexture?
    
    private var isPlaying: Bool = true
    private var lastTimestamp: CFTimeInterval = CACurrentMediaTime()
    
    // small uniforms (kept as properties so we aren’t making new vars every frame)
    
    private var scU32: UInt32 = 0
    private var sdU32: UInt32 = 0
    
    // x render: we step + render x mini-iterations per frame
    
    private let substeps = 1
    
    // 2-pass mode: after pass 1 settles, we snapshot and immediately re-run using that output as the new source
    
    private let totalPasses = 2
    private var currentPass = 1
    private var isSwitchingPass = false
    
    // keep the last inputs so we can reconfigure cleanly
    
    private var lastTargetImage: UIImage?
    
    // settle detection: “stop when it calms down” instead of guessing a time
    
    // lower threshold = needs to be more still before we count it as done
    
    // holdSeconds = how long it has to stay calm so we don’t stop on a random dip
    
    private let settleSpeedThreshold: Float = 0.18
    private let settleHoldSeconds: Float = 0.35
    
    private var settleTimer: Float = 0
    
    // just a safety so it doesn’t run forever on weird images
    
    private let maxSecondsPerPass: Float = 6.0
    
    // embedded Metal kernel for prototyping so i don’t have to deal with a separate .metal file
    
    // compute pass renders the morph into the 512 capture texture
    
    // render pass just stretches that texture fullscreen so the view stays normal size
    
    private static let metalSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct Seed { float x; float y; float ox; float oy; };
    
    struct FullscreenVertexOut {
        float4 position [[position]];
        float2 uv;
    };
    
    kernel void renderFullQuality(
        texture2d<float, access::write> outTex [[texture(0)]],
        texture2d<float, access::sample> srcTex [[texture(1)]],
        const device Seed* seeds [[buffer(0)]],
        constant uint& seedCount [[buffer(1)]],
        constant uint& simSide [[buffer(2)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        uint outW = outTex.get_width();
        uint outH = outTex.get_height();
        if (gid.x >= outW || gid.y >= outH) return;
    
        float sx = (float(gid.x) + 0.5f) * (float(simSide) / float(outW));
        float sy = (float(gid.y) + 0.5f) * (float(simSide) / float(outH));
        float2 p = float2(sx, sy);
    
        float bestD = FLT_MAX;
        uint bestI = 0;
        for (uint i = 0; i < seedCount; i++) {
            float2 s = float2(seeds[i].x, seeds[i].y);
            float2 d = s - p;
            float dist2 = dot(d, d);
            if (dist2 < bestD) { bestD = dist2; bestI = i; }
        }
    
        float2 moved = float2(seeds[bestI].x, seeds[bestI].y);
        float2 orig  = float2(seeds[bestI].ox, seeds[bestI].oy);
        float2 delta = p - moved;
        float2 sampleSim = orig + delta;
    
        float2 uv = sampleSim / float(simSide);
        uv = clamp(uv, float2(0.0f), float2(1.0f));
    
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        float4 c = srcTex.sample(s, uv);
        outTex.write(c, gid);
    }
    
    vertex FullscreenVertexOut presentVertex(uint vid [[vertex_id]]) {
        float2 positions[6] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2(-1.0,  1.0),
            float2( 1.0, -1.0),
            float2( 1.0,  1.0)
        };
        
        float2 uvs[6] = {
            float2(0.0, 1.0),
            float2(1.0, 1.0),
            float2(0.0, 0.0),
            float2(0.0, 0.0),
            float2(1.0, 1.0),
            float2(1.0, 0.0)
        };
        
        FullscreenVertexOut out;
        out.position = float4(positions[vid], 0.0, 1.0);
        out.uv = uvs[vid];
        return out;
    }
    
    fragment float4 presentFragment(
        FullscreenVertexOut in [[stage_in]],
        texture2d<float> tex [[texture(0)]]
    ) {
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        return tex.sample(s, in.uv);
    }
    """
    
    init?(mtkView: MTKView) {
        
        // set up the Metal device + command queue
        
        guard let dev = MTLCreateSystemDefaultDevice(),
              let q = dev.makeCommandQueue()
        else { return nil }
        
        self.device = dev
        self.queue = q
        self.textureLoader = MTKTextureLoader(device: dev)
        
        // compile the embedded kernel source and build the compute pipeline
        
        do {
            let library = try dev.makeLibrary(source: Self.metalSource, options: nil)
            
            guard let fn = library.makeFunction(name: "renderFullQuality"),
                  let vtx = library.makeFunction(name: "presentVertex"),
                  let frag = library.makeFunction(name: "presentFragment")
            else { return nil }
            
            self.pipeline = try dev.makeComputePipelineState(function: fn)
            
            let rpd = MTLRenderPipelineDescriptor()
            rpd.vertexFunction = vtx
            rpd.fragmentFunction = frag
            rpd.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            self.presentPipeline = try dev.makeRenderPipelineState(descriptor: rpd)
        } catch {
            print("Metal compile error:", error)
            return nil
        }
        
        super.init()
        
        // MTKView setup: render offscreen, then draw fullscreen to the drawable
        
        mtkView.device = dev
        mtkView.framebufferOnly = false
        
        // drawable still follows the real view size
        
        // capture texture stays fixed at 512 so compute stays cheaper
        
        mtkView.autoResizeDrawable = true
        
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.colorPixelFormat = .bgra8Unorm
        
        // fixed 512 capture again, because this is the texture used for the morph + snapshot
        
        self.captureTexture = makeCaptureTexture(width: 512, height: 512)
    }
    
    private func makeCaptureTexture(width: Int, height: Int) -> MTLTexture? {
        
        // texture the kernel writes into, and the same one we snapshot
        
        // this stays fixed at 512x512 for the cheaper internal render
        
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderWrite, .shaderRead]
        desc.storageMode = .private
        return device.makeTexture(descriptor: desc)
    }
    
    func setPlaying(_ playing: Bool) {
        
        // reset timestamp so unpausing doesn’t create a huge dt spike
        
        isPlaying = playing
        lastTimestamp = CACurrentMediaTime()
    }
    
    private func makeSourceTexture(from image: UIImage) -> MTLTexture? {
        
        // convert UIImage -> MTLTexture so the kernel can sample it
        
        guard let cg = image.cgImage else { return nil }
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft
        ]
        return try? textureLoader.newTexture(cgImage: cg, options: options)
    }
    
    func configure(source: UIImage, target: UIImage, simSide: Int = 64) {
        
        // rebuild the sim + GPU buffers for a new source/target
        
        self.lastTargetImage = target
        
        // whenever we configure from outside, we start over at pass 1
        
        self.currentPass = 1
        self.isSwitchingPass = false
        self.settleTimer = 0
        
        internalConfigure(source: source, target: target, simSide: simSide)
        
        // start playing for pass 1
        
        isPlaying = true
        lastTimestamp = CACurrentMediaTime()
    }
    
    private func internalConfigure(source: UIImage, target: UIImage, simSide: Int) {
        self.simSide = simSide
        self.sourceTexture = makeSourceTexture(from: source)
        
        // normalize images to simSide x simSide, then pull RGBA bytes for the CPU sim
        
        let srcCG = cgImageRGBA8(from: source, size: simSide)
        let tgtCG = cgImageRGBA8(from: target, size: simSide)
        
        let srcBytes = srcCG.map { bytesRGBA8(from: $0, size: simSide) } ?? [UInt8](repeating: 0, count: simSide * simSide * 4)
        let tgtBytes = tgtCG.map { bytesRGBA8(from: $0, size: simSide) } ?? [UInt8](repeating: 0, count: simSide * simSide * 4)
        
        let sim = InanimateArtSimulation(size: simSide, sourceRGBA: srcBytes, targetRGBA: tgtBytes)
        self.simulation = sim
        self.seedCount = sim.seedCount
        
        // cache uniforms
        
        self.scU32 = UInt32(seedCount)
        self.sdU32 = UInt32(simSide)
        
        // shared buffer so the CPU can update seed positions every frame
        
        seedBuffer = device.makeBuffer(length: MemoryLayout<MetalSeed>.stride * seedCount, options: [.storageModeShared])
        uploadSeeds()
    }
    
    private func uploadSeeds() {
        
        // copy the sim’s seed array into the GPU buffer
        
        guard let sim = simulation, let buf = seedBuffer, seedCount > 0 else { return }
        let ptr = buf.contents().bindMemory(to: MetalSeed.self, capacity: seedCount)
        for i in 0..<seedCount {
            let s = sim.seeds[i]
            ptr[i] = MetalSeed(x: s.x, y: s.y, ox: s.ox, oy: s.oy)
        }
    }
    
    func snapshot512() -> UIImage? {
        
        // read back the 512 capture texture into memory and return a UIImage
        
        // this is the exact texture used for the double-pass feedback step
        
        guard let tex = captureTexture else { return nil }
        
        let width = tex.width
        let height = tex.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height
        
        guard let cmd = queue.makeCommandBuffer(),
              let blit = cmd.makeBlitCommandEncoder(),
              let outBuffer = device.makeBuffer(length: byteCount, options: [.storageModeShared])
        else { return nil }
        
        blit.copy(
            from: tex,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: outBuffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: byteCount
        )
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: NSData(bytes: outBuffer.contents(), length: byteCount)) else { return nil }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(.byteOrder32Little)
        
        guard let cg = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        
        return UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        // drawable changes with the view, but the internal capture stays fixed
        
        // that’s the whole point of keeping the morph cheaper while still filling the screen
        
        if captureTexture == nil {
            captureTexture = makeCaptureTexture(width: 512, height: 512)
        }
    }
    
    private func updateSettleState(dt: Float) {
        guard let sim = simulation else { return }
        
        // if it’s calm, build up the settle timer
        
        // if it speeds up again, reset it
        
        if sim.averageSpeed <= settleSpeedThreshold {
            settleTimer += dt
        } else {
            settleTimer = 0
        }
    }
    
    private func shouldFinishCurrentPass() -> Bool {
        guard let sim = simulation else { return false }
        
        // finished if it’s been calm for long enough,
        
        // or if we hit the safety max runtime
        
        return settleTimer >= settleHoldSeconds || sim.elapsed >= maxSecondsPerPass
    }
    
    private func kickSecondPassOrFreeze() {
        guard simulation != nil else { return }
        
        // don’t do anything if we’re still actively moving
        
        if shouldFinishCurrentPass() == false { return }
        
        // pass 1 -> start pass 2
        
        if totalPasses >= 2, currentPass == 1 {
            guard isSwitchingPass == false else { return }
            guard let target = lastTargetImage else { return }
            
            isSwitchingPass = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                guard let img = self.snapshot512() else {
                    DispatchQueue.main.async { self.isSwitchingPass = false }
                    return
                }
                
                DispatchQueue.main.async {
                    
                    // switch to pass 2 and restart the sim using the pass 1 output as the new source
                    
                    self.currentPass = 2
                    self.isSwitchingPass = false
                    self.settleTimer = 0
                    
                    self.internalConfigure(source: img, target: target, simSide: self.simSide)
                    
                    // keep it playing for pass 2
                    
                    self.isPlaying = true
                    self.lastTimestamp = CACurrentMediaTime()
                }
            }
            
            return
        }
        
        // pass 2 -> freeze on final
        
        if currentPass == 2 {
            
            // stop morphing after 2 passes
            
            isPlaying = false
        }
    }
    
    func draw(in view: MTKView) {
        
        // render loop: step sim -> upload seeds -> run kernel into 512 texture -> draw fullscreen
        
        guard let drawable = view.currentDrawable,
              let buf = seedBuffer,
              let sim = simulation,
              let srcTex = sourceTexture,
              let outTex = captureTexture,
              seedCount > 0
        else { return }
        
        let now = CACurrentMediaTime()
        let dt = Float(now - lastTimestamp)
        lastTimestamp = now
        let clampedDt = min(max(dt, 0), 1.0 / 30.0)
        
        let subDt = clampedDt / Float(substeps)
        
        guard let cmd = queue.makeCommandBuffer() else { return }
        
        // 16x16 is usually a better fit here than the old auto-derived threadgroup
        
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        
        for _ in 0..<substeps {
            
            if isPlaying {
                sim.step(dt: subDt)
                uploadSeeds()
            }
            
            guard let enc = cmd.makeComputeCommandEncoder() else { break }
            
            enc.setComputePipelineState(pipeline)
            enc.setTexture(outTex, index: 0)
            enc.setTexture(srcTex, index: 1)
            enc.setBuffer(buf, offset: 0, index: 0)
            
            var sc = scU32
            var sd = sdU32
            enc.setBytes(&sc, length: MemoryLayout<UInt32>.size, index: 1)
            enc.setBytes(&sd, length: MemoryLayout<UInt32>.size, index: 2)
            
            enc.dispatchThreads(
                MTLSize(width: outTex.width, height: outTex.height, depth: 1),
                threadsPerThreadgroup: threadsPerThreadgroup
            )
            enc.endEncoding()
        }
        
        // instead of blitting 1:1 (which made the image tiny),
        
        // draw the 512 texture fullscreen with a tiny render pass
        
        if let rpd = view.currentRenderPassDescriptor,
           let presentEnc = cmd.makeRenderCommandEncoder(descriptor: rpd) {
            presentEnc.setRenderPipelineState(presentPipeline)
            presentEnc.setFragmentTexture(outTex, index: 0)
            presentEnc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            presentEnc.endEncoding()
        }
        
        cmd.present(drawable)
        cmd.commit()
        
        // update settle detection and flip passes / freeze if needed
        
        if isPlaying {
            updateSettleState(dt: clampedDt)
            kickSecondPassOrFreeze()
        }
    }
}
