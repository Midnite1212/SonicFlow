// Turns square logo artwork into a 1024 px app icon: the rounded body cropped from its black
// surround and placed on Apple's icon grid with transparent corners.
// Usage: swift scripts/make-icon.swift <artwork.png> <output.png>
import AppKit

let source = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))!
let output = URL(fileURLWithPath: CommandLine.arguments[2])

func lit(_ x: Int, _ y: Int) -> Bool {
    let c = source.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    return max(c.redComponent, c.greenComponent, c.blueComponent) > 0.02
}

let w = source.pixelsWide, h = source.pixelsHigh
let midX = w / 2, midY = h / 2
let left = (0..<w).first { lit($0, midY) }!
let right = (0..<w).last { lit($0, midY) }!
let top = (0..<h).first { lit(midX, $0) }!
let bottom = (0..<h).last { lit(midX, $0) }!
let body = CGRect(x: left, y: h - 1 - bottom, width: right - left + 1, height: bottom - top + 1)

let canvas = 1024, side = 824.0, radius = side * 0.225
let inset = (Double(canvas) - side) / 2
let target = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
let frame = NSRect(x: inset, y: inset, width: side, height: side)
NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
let image = NSImage(size: NSSize(width: w, height: h))
image.addRepresentation(source)
let margin = body.width * 0.006
image.draw(in: frame, from: body.insetBy(dx: margin, dy: margin), operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try target.representation(using: .png, properties: [:])!.write(to: output)
print(output.path)
