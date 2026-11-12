#!/usr/bin/env swift
// Generates the Disk Free app icon PNGs from DiskFree/art/AppIcon-source.png.
// Contents.json in the appiconset is maintained by hand and is not touched.
// Usage: swift DiskFree/scripts/make-icon.swift [output-dir]
import AppKit
import CoreGraphics
import Foundation

let scriptsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let rootDir = scriptsDir.deletingLastPathComponent()
let defaultDir = rootDir.appendingPathComponent("DiskFree/Assets.xcassets/AppIcon.appiconset").path
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultDir
let sourceURL = rootDir.appendingPathComponent("art/AppIcon-source.png")

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("make-icon: \(msg)\n".utf8))
    exit(1)
}

guard let src = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fail("cannot read \(sourceURL.path)") }
let W = image.width, H = image.height

// Find the tile's bounding box: pixels that are not near-black.
func tileBounds() -> CGRect {
    var buf = [UInt8](repeating: 0, count: W * H * 4)
    let ctx = CGContext(data: &buf, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                        space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
    var minX = W, minY = H, maxX = -1, maxY = -1
    for y in 0..<H {
        for x in 0..<W {
            let i = (y * W + x) * 4
            if max(buf[i], buf[i + 1], buf[i + 2]) > 40 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
    }
    if maxX < 0 { fail("no tile found in source") }
    // Buffer rows are top-first; return in image (top-left origin) coordinates.
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}
let box = tileBounds()
let inset: CGFloat = 6   // source pixels, to drop anti-aliased black fringe

func render(_ ctx: CGContext, size s: CGFloat) {
    let u = s / 1024
    // macOS grid: 824 tile centred in a 1024 canvas.
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let scale = tile.width / box.width
    // Clip rect in source coordinates (bottom-left origin).
    let clipSrc = CGRect(x: box.minX + inset, y: CGFloat(H) - box.maxY + inset,
                         width: box.width - 2 * inset, height: box.height - 2 * inset)
    let radius = (185.0 / 824.0) * box.width - inset
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * u), blur: 24 * u,
                  color: CGColor(colorSpace: srgb, components: [0, 0, 0, 0.35])!)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.translateBy(x: tile.minX, y: tile.minY)
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -box.minX, y: -(CGFloat(H) - box.maxY))
    ctx.addPath(CGPath(roundedRect: clipSrc, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func makePNG(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)!
    let bmp = rep.retagging(with: NSColorSpace.sRGB) ?? rep
    let ctx = CGContext(data: bmp.bitmapData, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: bmp.bytesPerRow, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    render(ctx, size: CGFloat(size))
    return bmp.representation(using: .png, properties: [:])!
}

// Self-check: exact pixel size, alpha channel, transparent corners, opaque centre.
func check(_ url: URL, px: Int) {
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fail("cannot reread \(url.lastPathComponent)") }
    if img.width != px || img.height != px { fail("\(url.lastPathComponent) is \(img.width)x\(img.height), expected \(px)") }
    switch img.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast: fail("\(url.lastPathComponent) has no alpha channel")
    default: break
    }
    let rep = NSBitmapImageRep(cgImage: img)
    func alpha(_ x: Int, _ y: Int) -> CGFloat { rep.colorAt(x: x, y: y)?.alphaComponent ?? -1 }
    if px == 1024 {
        for (x, y) in [(0, 0), (px - 1, 0), (0, px - 1), (px - 1, px - 1)] where alpha(x, y) != 0 {
            fail("corner (\(x),\(y)) of \(url.lastPathComponent) is not transparent")
        }
        if alpha(512, 512) != 1 { fail("centre of \(url.lastPathComponent) is not opaque") }
    }
}

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var count = 0
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
        try makePNG(size: px).write(to: url)
        check(url, px: px)
        count += 1
    }
}
print("Wrote \(count) icons to \(outDir)")
