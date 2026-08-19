import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Could not get graphics context")
}

let rect = NSRect(origin: .zero, size: size)

// Rounded-rect clip
let insetRect = rect.insetBy(dx: 8, dy: 8)
let corner: CGFloat = 224
let clip = NSBezierPath(roundedRect: insetRect, xRadius: corner, yRadius: corner)
clip.addClip()

// Gradient background
let colors = [
    NSColor(calibratedRed: 0.10, green: 0.62, blue: 0.68, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.15, green: 0.36, blue: 0.75, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 1024),
                           end: CGPoint(x: 512, y: 0),
                           options: [])

// ECG waveform
let waveform = NSBezierPath()
waveform.lineWidth = 46
waveform.lineCapStyle = .round
waveform.lineJoinStyle = .round
let points: [(CGFloat, CGFloat)] = [
    (150, 560), (260, 560), (320, 560), (350, 560), (395, 700),
    (440, 330), (500, 560), (560, 800), (610, 300), (665, 650),
    (700, 560), (760, 560), (860, 560),
]
waveform.move(to: CGPoint(x: points[0].0, y: points[0].1))
for p in points.dropFirst() {
    waveform.line(to: CGPoint(x: p.0, y: p.1))
}
NSColor.white.withAlphaComponent(0.95).setStroke()
waveform.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Could not render PNG")
}

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"
try! png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
