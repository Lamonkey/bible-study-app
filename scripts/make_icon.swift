// make_icon: flat icon artwork on a plain background -> macOS-shaped 1024px icon tile (PNG).
//
//   1. Flood-fill the background in from the four corners (so enclosed areas of the same
//      colour, such as white text or book pages, are left alone).
//   2. Erode a few pixels to remove the anti-aliased fringe that would show as a halo.
//   3. Bleed the artwork's edge colours out over the removed background, so nothing of the
//      old background can show where the artwork's corners differ from Apple's shape.
//   4. Scale the artwork's bounding box onto the 824x824 tile of a 1024 canvas, clip to the
//      continuous-corner squircle, add the standard soft drop shadow.
//
// Usage: make_icon <source-image> <out-1024.png> [--tolerance N] [--erode N]
//                  [--full-bleed] [--no-shadow]
import AppKit
import SwiftUI

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

var positional = [String]()
var tolerance = 55, erode = 3, fullBleed = false, shadow = true
var it = CommandLine.arguments.dropFirst().makeIterator()
while let a = it.next() {
    switch a {
    case "--tolerance": tolerance = Int(it.next() ?? "") ?? tolerance
    case "--erode": erode = Int(it.next() ?? "") ?? erode
    case "--full-bleed": fullBleed = true
    case "--no-shadow": shadow = false
    default: positional.append(a)
    }
}
guard positional.count == 2 else {
    fail("usage: make_icon <source-image> <out-1024.png> [--tolerance N] [--erode N] [--full-bleed] [--no-shadow]")
}
guard let srcImage = NSImage(contentsOfFile: positional[0]),
      let srcCG = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fail("cannot read image: \(positional[0])")
}

let w = srcCG.width, h = srcCG.height
if w != h { print("note: source is \(w)x\(h), not square; the artwork's bounding box will be stretched to a square tile") }
if min(w, h) < 1024 { print("note: source is smaller than 1024px; the icon will be upscaled and may look soft") }
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGImageAlphaInfo.premultipliedLast.rawValue
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!
ctx.draw(srcCG, in: CGRect(x: 0, y: 0, width: w, height: h))

func neighbours(_ i: Int) -> [Int] {
    let x = i % w, y = i / w
    var n = [Int]()
    if x > 0 { n.append(i - 1) }; if x < w - 1 { n.append(i + 1) }
    if y > 0 { n.append(i - w) }; if y < h - 1 { n.append(i + w) }
    return n
}

var bg = [Bool](repeating: false, count: w * h)
if !fullBleed {
    // The background is whatever the corners are: transparent, or one flat colour.
    let corners = [0, w - 1, (h - 1) * w, h * w - 1]
    let transparentCorners = corners.allSatisfy { px[$0 * 4 + 3] < 128 }
    func rgb(_ i: Int) -> [Int] { (0..<3).map { Int(px[i * 4 + $0]) } }
    func dist(_ a: [Int], _ b: [Int]) -> Int { zip(a, b).map { abs($0 - $1) }.max()! }
    let ref = (0..<3).map { k in corners.map { rgb($0)[k] }.reduce(0, +) / 4 }
    if !transparentCorners {
        let spread = corners.map { dist(rgb($0), ref) }.max()!
        if spread > tolerance {
            fail("the four corners differ in colour (spread \(spread)), so this is not a flat background. "
               + "If the artwork fills the whole canvas use --full-bleed; otherwise the background needs manual removal.")
        }
    }
    func isBackground(_ i: Int) -> Bool {
        transparentCorners ? px[i * 4 + 3] < 128 : (px[i * 4 + 3] > 127 && dist(rgb(i), ref) <= tolerance)
    }
    var queue = corners.filter(isBackground)
    for c in queue { bg[c] = true }
    var head = 0
    while head < queue.count {
        let i = queue[head]; head += 1
        for n in neighbours(i) where !bg[n] && isBackground(n) { bg[n] = true; queue.append(n) }
    }
    for _ in 0..<erode {
        let edge = (0..<(w * h)).filter { i in !bg[i] && neighbours(i).contains { bg[$0] } }
        for i in edge { bg[i] = true }
    }
    let share = Double(bg.filter { $0 }.count) / Double(w * h)
    print(String(format: "background: %@, %.0f%% of the image removed",
                 transparentCorners ? "transparent" : "rgb(\(ref[0]),\(ref[1]),\(ref[2]))", share * 100))
    if share == 0 { print("note: no background found; treating the artwork as full-bleed") }
    if share > 0.7 { print("WARNING: more than 70% removed. The artwork is tiny, or its own colour matches the background and was eaten. Look at the result; try a lower --tolerance or --full-bleed.") }
}

var minX = w, maxX = 0, minY = h, maxY = 0
for y in 0..<h { for x in 0..<w where !bg[y * w + x] {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
} }
guard minX < maxX, minY < maxY else { fail("nothing left after background removal; try a lower --tolerance") }
// A shape on a canvas is inset from the image edges. If the artwork still reaches all four
// edges, the corner colour belonged to the artwork itself and the fill has eaten into it.
if !fullBleed, bg.contains(true), minX <= 1, minY <= 1, maxX >= w - 2, maxY >= h - 2 {
    print("note: the artwork reaches all four edges, so the corner colour is part of it, not a canvas. Treating as --full-bleed and keeping every pixel.")
    bg = [Bool](repeating: false, count: w * h)
}

// Bleed edge colours outward: multi-source BFS from the artwork boundary.
var filled = bg.map { !$0 }
var frontier = (0..<(w * h)).filter { i in filled[i] && neighbours(i).contains { !filled[$0] } }
while !frontier.isEmpty {
    var next = [Int]()
    for i in frontier { for n in neighbours(i) where !filled[n] {
        filled[n] = true
        let a = max(Int(px[i * 4 + 3]), 1)          // un-premultiply so bled colour is opaque
        for k in 0..<3 { px[n * 4 + k] = UInt8(min(255, Int(px[i * 4 + k]) * 255 / a)) }
        px[n * 4 + 3] = 255
        next.append(n)
    } }
    frontier = next
}
let bled = ctx.makeImage()!

let size = 1024
let out = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
out.interpolationQuality = .high
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = RoundedRectangle(cornerRadius: 185.4, style: .continuous).path(in: tile).cgPath

if shadow {
    out.saveGState()
    out.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: CGColor(gray: 0, alpha: 0.3))
    out.addPath(shape); out.setFillColor(CGColor(gray: 0, alpha: 1)); out.fillPath()
    out.restoreGState()
}
out.saveGState()
out.addPath(shape); out.clip()
// Pixel rows count from the top, CoreGraphics from the bottom.
let bw = CGFloat(maxX - minX + 1), bh = CGFloat(maxY - minY + 1)
let sx = tile.width / bw, sy = tile.height / bh
out.draw(bled, in: CGRect(x: tile.minX - CGFloat(minX) * sx, y: tile.minY - CGFloat(h - 1 - maxY) * sy,
                          width: CGFloat(w) * sx, height: CGFloat(h) * sy))
out.restoreGState()

let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
do { try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: positional[1])) }
catch { fail("cannot write \(positional[1]): \(error)") }
print("artwork bounds: x \(minX)-\(maxX), y \(minY)-\(maxY) of \(w)x\(h)")
print("wrote \(positional[1])")
