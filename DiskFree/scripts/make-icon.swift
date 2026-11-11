#!/usr/bin/env swift
// Generates the Disk Free app icon PNGs and Contents.json.
// Usage: swift DiskFree/scripts/make-icon.swift [output-dir]
import AppKit
import CoreGraphics
import Foundation

let defaultDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("DiskFree/Assets.xcassets/AppIcon.appiconset").path
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultDir

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: srgb, components: [r, g, b, a])!
}

func draw(_ ctx: CGContext, size s: CGFloat) {
    let u = s / 1024
    // macOS grid: 824pt tile centred in 1024 canvas.
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    // Shadow + tile gradient
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * u), blur: 24 * u, color: col(0, 0, 0, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(col(0.2, 0.22, 0.28)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let bg = CGGradient(colorsSpace: srgb, colors: [col(0.30, 0.33, 0.42), col(0.10, 0.11, 0.16)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    ctx.restoreGState()

    let c = CGPoint(x: 512 * u, y: 512 * u)
    // Platter
    let pr = 270 * u
    ctx.setFillColor(col(0.88, 0.90, 0.94))
    ctx.fillEllipse(in: CGRect(x: c.x - pr, y: c.y - pr, width: pr * 2, height: pr * 2))
    ctx.setFillColor(col(0.10, 0.11, 0.16))
    let ir = 205 * u
    ctx.fillEllipse(in: CGRect(x: c.x - ir, y: c.y - ir, width: ir * 2, height: ir * 2))
    // Gauge arc: used (blue -> red) around a ring, remainder dim.
    let ringR = 235 * u, lw = 56 * u
    ctx.setLineWidth(lw); ctx.setLineCap(.round)
    let start = CGFloat.pi / 2          // top
    let total = CGFloat.pi * 2
    ctx.setStrokeColor(col(0.25, 0.27, 0.34))
    ctx.addArc(center: c, radius: ringR - 0, startAngle: 0, endAngle: total, clockwise: false)
    ctx.strokePath()
    let steps = 90
    let used: CGFloat = 0.72
    for i in 0..<steps {
        let t0 = CGFloat(i) / CGFloat(steps), t1 = CGFloat(i + 1) / CGFloat(steps)
        let f = t0
        ctx.setStrokeColor(col(0.15 + 0.80 * f, 0.50 - 0.30 * f, 1.0 - 0.80 * f))
        ctx.setLineCap(i == 0 ? .round : .butt)
        ctx.addArc(center: c, radius: ringR, startAngle: start - t0 * used * total,
                   endAngle: start - (t1 * used * total) - 0.004, clockwise: true)
        ctx.strokePath()
    }
    // Spindle hub and arm
    ctx.setFillColor(col(0.88, 0.90, 0.94))
    let hr = 60 * u
    ctx.fillEllipse(in: CGRect(x: c.x - hr, y: c.y - hr, width: hr * 2, height: hr * 2))
    ctx.setFillColor(col(0.10, 0.11, 0.16))
    let dr = 22 * u
    ctx.fillEllipse(in: CGRect(x: c.x - dr, y: c.y - dr, width: dr * 2, height: dr * 2))
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)!
    let bmp = rep.retagging(with: NSColorSpace.sRGB) ?? rep
    let ctx = CGContext(data: bmp.bitmapData, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: bmp.bytesPerRow, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    draw(ctx, size: CGFloat(size))
    return bmp.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try png(size: px).write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(base)x\(base)"])
    }
}
let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(outDir)")
