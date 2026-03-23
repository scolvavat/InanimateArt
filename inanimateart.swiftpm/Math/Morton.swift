import Foundation

// Morton (Z-order) helper:
// I use this to sort pixels in a way that preserves 2D locality,

// so assignments/matching don't jump around the image as much.

// Basically, Bit-interleaving step: spreads the lower 16 bits out so i can interleave X and Y

func part1By1(_ x: UInt32) -> UInt32 {
    var v = x & 0x0000ffff
    v = (v | (v << 8)) & 0x00FF00FF
    v = (v | (v << 4)) & 0x0F0F0F0F
    v = (v | (v << 2)) & 0x33333333
    v = (v | (v << 1)) & 0x55555555
    return v
}


func morton2D(x: Int, y: Int) -> UInt32 {
    let xx = part1By1(UInt32(x))
    let yy = part1By1(UInt32(y))
    return xx | (yy << 1)
}
