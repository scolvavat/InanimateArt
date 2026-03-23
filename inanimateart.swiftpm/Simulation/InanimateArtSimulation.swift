import Foundation

// one seed = one “pixel token” in the sim

// x/y = current position (moves over time)

// ox/oy = original position (used so sampling stays consistent)

struct SimSeed {
    var x: Float
    var y: Float
    var ox: Float
    var oy: Float
}

// CPU sim that decides where each seed should move

// renderer reads the updated seeds each frame and draws the warp

final class InanimateArtSimulation {
    let size: Int
    let seedCount: Int
    
    private(set) var seeds: [SimSeed]
    private var vx: [Float]
    private var vy: [Float]
    
    // destination position for each seed (where it’s trying to end up)
    
    private var dstX: [Float]
    private var dstY: [Float]
    
    // keeps track of which seeds already got a destination
    
    private var assigned: [Bool]
    
    // little timer so motion can ramp in instead of snapping
    
    private(set) var elapsed: Float = 0
    
    // quick “are we basically done yet?” number for the renderer
    
    var averageSpeed: Float {
        if seedCount == 0 { return 0 }
        var sum: Float = 0
        for i in 0..<seedCount {
            sum += hypotf(vx[i], vy[i])
        }
        return sum / Float(seedCount)
    }
    
    init(size: Int, sourceRGBA: [UInt8], targetRGBA: [UInt8]) {
        self.size = size
        self.seedCount = size * size
        
        self.seeds = []
        self.seeds.reserveCapacity(seedCount)
        
        // speed buffers so motion is smooth (damped spring vibe)
        
        self.vx = [Float](repeating: 0, count: seedCount)
        self.vy = [Float](repeating: 0, count: seedCount)
        
        self.dstX = [Float](repeating: 0, count: seedCount)
        self.dstY = [Float](repeating: 0, count: seedCount)
        self.assigned = [Bool](repeating: false, count: seedCount)
        
        // brightness matching: map source pixels -> target pixels by brightness bins first so it looks less random
        
        var sourceLum = [Float](repeating: 0, count: seedCount)
        var targetLum = [Float](repeating: 0, count: seedCount)
        
        for y in 0..<size {
            for x in 0..<size {
                let idx = y * size + x
                
                // seeds start centered in their original grid cell
                
                let fx = Float(x) + 0.5
                let fy = Float(y) + 0.5
                seeds.append(SimSeed(x: fx, y: fy, ox: fx, oy: fy))
                
                // compute luminance from RGB (ignore alpha)
                
                let sr = sourceRGBA[idx*4 + 0]
                let sg = sourceRGBA[idx*4 + 1]
                let sb = sourceRGBA[idx*4 + 2]
                sourceLum[idx] = luminance01(r: sr, g: sg, b: sb)
                
                let tr = targetRGBA[idx*4 + 0]
                let tg = targetRGBA[idx*4 + 1]
                let tb = targetRGBA[idx*4 + 2]
                targetLum[idx] = luminance01(r: tr, g: tg, b: tb)
            }
        }
        
        // brightness bucketing (16 bins)
        
        // cheap way to line up dark->dark and bright->bright before the spatial ordering
        
        let bins = 16
        func binIndex(_ lum: Float) -> Int {
            let b = Int((lum * Float(bins - 1)).rounded(.towardZero))
            return clamp(b, 0, bins - 1)
        }
        
        var srcBins = Array(repeating: [Int](), count: bins)
        var tgtBins = Array(repeating: [Int](), count: bins)
        
        for i in 0..<seedCount { srcBins[binIndex(sourceLum[i])].append(i) }
        for i in 0..<seedCount { tgtBins[binIndex(targetLum[i])].append(i) }
        
        // inside each bin, sort by morton order (z-order curve)
        
        // keeps matches more local instead of scattering across the whole image
        
        for b in 0..<bins {
            srcBins[b].sort {
                let x0 = $0 % size, y0 = $0 / size
                let x1 = $1 % size, y1 = $1 / size
                return morton2D(x: x0, y: y0) < morton2D(x: x1, y: y1)
            }
            tgtBins[b].sort {
                let x0 = $0 % size, y0 = $0 / size
                let x1 = $1 % size, y1 = $1 / size
                return morton2D(x: x0, y: y0) < morton2D(x: x1, y: y1)
            }
        }
        
        var srcCursor = Array(repeating: 0, count: bins)
        var tgtCursor = Array(repeating: 0, count: bins)
        
        // greedy matching helper: if the exact bin is empty, expand outward to neighboring bins
        
        func takeNextSrc(from startBin: Int) -> Int? {
            for radius in 0..<bins {
                let lo = startBin - radius
                let hi = startBin + radius
                if lo >= 0, srcCursor[lo] < srcBins[lo].count {
                    let idx = srcBins[lo][srcCursor[lo]]
                    srcCursor[lo] += 1
                    return idx
                }
                if hi < bins, hi != lo, srcCursor[hi] < srcBins[hi].count {
                    let idx = srcBins[hi][srcCursor[hi]]
                    srcCursor[hi] += 1
                    return idx
                }
            }
            return nil
        }
        
        func takeNextTgt(from startBin: Int) -> Int? {
            for radius in 0..<bins {
                let lo = startBin - radius
                let hi = startBin + radius
                if lo >= 0, tgtCursor[lo] < tgtBins[lo].count {
                    let idx = tgtBins[lo][tgtCursor[lo]]
                    tgtCursor[lo] += 1
                    return idx
                }
                if hi < bins, hi != lo, tgtCursor[hi] < tgtBins[hi].count {
                    let idx = tgtBins[hi][tgtCursor[hi]]
                    tgtCursor[hi] += 1
                    return idx
                }
            }
            return nil
        }
        
        // build the destination position for each source seed
        
        // sIdx = source seed index, tIdx = target pixel index
        
        for b in 0..<bins {
            while true {
                guard let tIdx = takeNextTgt(from: b) else { break }
                guard let sIdx = takeNextSrc(from: b) else { break }
                
                let tx = tIdx % size
                let ty = tIdx / size
                dstX[sIdx] = Float(tx) + 0.5
                dstY[sIdx] = Float(ty) + 0.5
                assigned[sIdx] = true
            }
        }
        
        // fallback: any unassigned seeds just keep their original spot
        
        for i in 0..<seedCount where !assigned[i] {
            let x = i % size
            let y = i / size
            dstX[i] = Float(x) + 0.5
            dstY[i] = Float(y) + 0.5
            assigned[i] = true
        }
    }
    
    // step the sim forward by dt
    
    func step(dt: Float) {
        elapsed += dt
        
        // damped spring motion toward dstX/dstY
        
        // ramp eases in the motion so it doesn’t snap on frame 1
        
        let damping: Float = 0.90
        let maxV: Float = 6.0
        let ramp = min(1.0, elapsed * 0.8)
        let k: Float = 10.0 * ramp
        
        // push velocity toward the destination
        
        for i in 0..<seedCount {
            let dx = dstX[i] - seeds[i].x
            let dy = dstY[i] - seeds[i].y
            vx[i] += dx * dt * k
            vy[i] += dy * dt * k
        }
        
        // apply damping + clamp speed + integrate position
        
        for i in 0..<seedCount {
            vx[i] *= damping
            vy[i] *= damping
            vx[i] = clamp(vx[i], -maxV, maxV)
            vy[i] = clamp(vy[i], -maxV, maxV)
            
            // keep seeds inside the sim bounds
            
            seeds[i].x = clamp(seeds[i].x + vx[i], 0.5, Float(size) - 0.5)
            seeds[i].y = clamp(seeds[i].y + vy[i], 0.5, Float(size) - 0.5)
        }
    }
}
