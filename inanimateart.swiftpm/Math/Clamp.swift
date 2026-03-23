import Foundation

// Tiny helper used all over the project to keep values in a safe range.

func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }
