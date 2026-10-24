#!/usr/bin/env swift
// Draws the app icon (files in a tray) and writes Shelf/Resources/Assets.xcassets/AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift
import AppKit

// The artwork is laid out on a 100-unit design grid (y down); the icon body spans 6...94.
let designBody = CGRect(x: 6, y: 6, width: 88, height: 88)
// macOS icon grid on a 1024 canvas: an 824-point body inset by 100.
let bodyInset = 100.0 / 1024.0
let cornerRatio = 185.4 / 824.0

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func fillRoundedRect(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, rotation degrees: CGFloat,
                     around center: CGPoint, _ fill: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.translateBy(x: -center.x, y: -center.y)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.restoreGState()
}

func trayPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 22, y: 54))
    path.addLine(to: CGPoint(x: 37, y: 54))
    path.addLine(to: CGPoint(x: 41, y: 61))
    path.addLine(to: CGPoint(x: 59, y: 61))
    path.addLine(to: CGPoint(x: 63, y: 54))
    path.addLine(to: CGPoint(x: 78, y: 54))
    path.addLine(to: CGPoint(x: 78, y: 68))
    path.addArc(tangent1End: CGPoint(x: 78, y: 73), tangent2End: CGPoint(x: 73, y: 73), radius: 5)
    path.addLine(to: CGPoint(x: 27, y: 73))
    path.addArc(tangent1End: CGPoint(x: 22, y: 73), tangent2End: CGPoint(x: 22, y: 68), radius: 5)
    path.closeSubpath()
    return path
}

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let size = CGFloat(pixels)
    // Flip to y-down so the coordinates match the design grid.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let body = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * bodyInset, dy: size * bodyInset)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: body.width * cornerRatio,
                          cornerHeight: body.width * cornerRatio, transform: nil)

    // Body with a soft drop shadow. Shadow offsets ignore the flip, so a negative y falls downward.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.02,
                  color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x185FA5))
    ctx.fillPath()
    ctx.restoreGState()

    // Gentle top-to-bottom shading inside the body.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let shading = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                             colors: [color(0x2471BD), color(0x14528F)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shading, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: [])
    ctx.restoreGState()

    // Map the design grid onto the body.
    let scale = body.width / designBody.width
    ctx.translateBy(x: body.minX, y: body.minY)
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -designBody.minX, y: -designBody.minY)

    // The inside of the tray, seen through the dip in its front edge.
    ctx.setFillColor(color(0x0C447C))
    ctx.fill(CGRect(x: 30, y: 54, width: 40, height: 10))

    // At 32 px and below the back file blurs into the front one, so it is left out.
    // The files run down into the tray, below its front edge.
    if pixels > 32 {
        fillRoundedRect(ctx, CGRect(x: 31, y: 26, width: 19, height: 38), radius: 2.5, rotation: -7,
                        around: CGPoint(x: 40, y: 42), color(0x85B7EB))
    }
    fillRoundedRect(ctx, CGRect(x: 48, y: 22, width: 21, height: 42), radius: 2.5, rotation: 6,
                    around: CGPoint(x: 58, y: 40), color(0xE6F1FB))
    ctx.addPath(trayPath())
    ctx.setFillColor(color(0xB5D4F4))
    ctx.fillPath()

    return rep
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("../Shelf/Resources/Assets.xcassets/AppIcon.appiconset").standardized
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let filename = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        let data = render(pixels: points * factor).representation(using: .png, properties: [:])!
        try data.write(to: outputDir.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "scale": "\(factor)x", "size": "\(points)x\(points)"])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDir.appendingPathComponent("Contents.json"))
print(outputDir.path)
