#!/usr/bin/swift
// Generates the Malayalam Panchangam Calendar app icon PNG files.
// Run from the repo root: swift script/generate-icon.swift
import AppKit
import CoreGraphics

let outputDir = "Sources/MalayalamPanchangamCalendar/Resources/Assets.xcassets/AppIcon.appiconset"

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // ── Background: deep indigo gradient ──────────────────────────────────
    let bgTop    = CGColor(red: 0.09, green: 0.10, blue: 0.26, alpha: 1)
    let bgBottom = CGColor(red: 0.04, green: 0.05, blue: 0.14, alpha: 1)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let grad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBottom] as CFArray,
                                locations: [0.0, 1.0]) else {
        image.unlockFocus(); return image
    }
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: 0, y: 0),
                           options: [])

    let cx = s / 2, cy = s / 2

    // ── Outer ring of 27 dots (nakshatras) ────────────────────────────────
    let ringRadius = s * 0.42
    let dotRadius  = s * 0.018
    ctx.setFillColor(CGColor(red: 0.78, green: 0.78, blue: 1.0, alpha: 0.55))
    for i in 0..<27 {
        let angle = CGFloat(i) * (2.0 * .pi / 27.0) - .pi / 2
        let dx = cx + ringRadius * cos(angle)
        let dy = cy + ringRadius * sin(angle)
        ctx.fillEllipse(in: CGRect(x: dx - dotRadius, y: dy - dotRadius,
                                    width: dotRadius * 2, height: dotRadius * 2))
    }

    // ── Sun circle (gold) ─────────────────────────────────────────────────
    let sunR = s * 0.24
    let sunGrad: CGGradient = {
        let c1 = CGColor(red: 1.00, green: 0.82, blue: 0.20, alpha: 1)
        let c2 = CGColor(red: 0.92, green: 0.55, blue: 0.05, alpha: 1)
        return CGGradient(colorsSpace: cs, colors: [c1, c2] as CFArray, locations: [0, 1])!
    }()
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - sunR, y: cy - sunR, width: sunR * 2, height: sunR * 2))
    ctx.clip()
    ctx.drawRadialGradient(sunGrad,
                            startCenter: CGPoint(x: cx - sunR * 0.25, y: cy + sunR * 0.25),
                            startRadius: 0,
                            endCenter: CGPoint(x: cx, y: cy),
                            endRadius: sunR,
                            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // ── 8 sun rays ────────────────────────────────────────────────────────
    let rayColor = CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.85)
    ctx.setStrokeColor(rayColor)
    ctx.setLineWidth(s * 0.016)
    ctx.setLineCap(.round)
    let rayInner = sunR * 1.18
    let rayOuter = sunR * 1.60
    for i in 0..<8 {
        let angle = CGFloat(i) * (.pi / 4)
        ctx.move(to: CGPoint(x: cx + rayInner * cos(angle), y: cy + rayInner * sin(angle)))
        ctx.addLine(to: CGPoint(x: cx + rayOuter * cos(angle), y: cy + rayOuter * sin(angle)))
    }
    ctx.strokePath()

    // ── Crescent moon overlay (silver) ────────────────────────────────────
    // Draw a full circle then cut a smaller offset circle from it.
    let moonR   = sunR * 0.50
    let moonOff = moonR * 0.60
    // Moon body
    ctx.setFillColor(CGColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1))
    ctx.addEllipse(in: CGRect(x: cx - moonR + sunR * 0.40,
                               y: cy - moonR + sunR * 0.40,
                               width: moonR * 2, height: moonR * 2))
    ctx.fillPath()
    // Bite out of moon with background color
    ctx.setFillColor(bgBottom)
    let biteCX = cx + sunR * 0.40 + moonOff * 0.85
    let biteCY = cy + sunR * 0.40 + moonOff * 0.30
    let biteR  = moonR * 0.80
    ctx.addEllipse(in: CGRect(x: biteCX - biteR, y: biteCY - biteR,
                               width: biteR * 2, height: biteR * 2))
    ctx.fillPath()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, name: String) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("⚠️  Could not get CGImage for \(name)")
        return
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = image.size
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("⚠️  Could not create PNG data for \(name)")
        return
    }
    let path = "\(outputDir)/\(name).png"
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("✅ \(path) (\(Int(image.size.width))px)")
    } catch {
        print("❌ Failed to write \(path): \(error)")
    }
}

for (name, px) in sizes {
    savePNG(drawIcon(size: px), name: name)
}
print("Done.")
