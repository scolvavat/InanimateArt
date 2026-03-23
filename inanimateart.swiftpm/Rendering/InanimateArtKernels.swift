import Foundation

// Holds the embedded Metal shader source (MSL) as a single string.

// The renderer compiles this with makeLibrary(source:options:).

enum InanimateArtKernels {

    // Renders a warped frame by:
    
    // mapping each output pixel into sim-space
    
    // picking the nearest moved seed (Voronoi cell)
    
    // sampling the source using the seed’s original position + local offset

    static let metalSource = """
    #include <metal_stdlib>
    using namespace metal;

    // Must match Swift's seed layout.
    
    // x/y  = current (moved) position in sim-space
    
    // ox/oy = original position in sim-space (used for sampling)
    struct Seed { float x; float y; float ox; float oy; };

    kernel void renderFullQuality(
        texture2d<float, access::write> outTex [[texture(0)]],      // final frame
        texture2d<float, access::sample> srcTex [[texture(1)]],     // source image
        const device Seed* seeds [[buffer(0)]],                     // seed list
        constant uint& seedCount [[buffer(1)]],                     // simSide * simSide
        constant uint& simSide [[buffer(2)]],                       // e.g. 64
        uint2 gid [[thread_position_in_grid]]                       // output pixel
    ) {
        uint outW = outTex.get_width();
        uint outH = outTex.get_height();
        if (gid.x >= outW || gid.y >= outH) return;

        // Output pixel -> sim-space (resolution independent).
    
        float sx = (float(gid.x) + 0.5f) * (float(simSide) / float(outW));
        float sy = (float(gid.y) + 0.5f) * (float(simSide) / float(outH));
        float2 p = float2(sx, sy);

        // Nearest seed (brute force; fine for small sims like 64x64).
    
        float bestD = FLT_MAX;
        uint bestI = 0;
        for (uint i = 0; i < seedCount; i++) {
            float2 s = float2(seeds[i].x, seeds[i].y);
            float2 d = s - p;
            float dist2 = dot(d, d);
            if (dist2 < bestD) { bestD = dist2; bestI = i; }
        }

        // Keep local offset inside the moved cell, but sample from the original cell.
    
        float2 moved = float2(seeds[bestI].x,  seeds[bestI].y);
        float2 orig  = float2(seeds[bestI].ox, seeds[bestI].oy);
        float2 sampleSim = orig + (p - moved);

        // Sim-space -> UVs, clamp, sample.
    
        float2 uv = clamp(sampleSim / float(simSide), float2(0.0f), float2(1.0f));
        constexpr sampler s(address::clamp_to_edge, filter::linear);

        float4 c = srcTex.sample(s, uv);
        outTex.write(c, gid);
    }
    """
}
