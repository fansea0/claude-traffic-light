import AppKit
import CoreGraphics

func drawTrafficLight(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = CGFloat(size)
    let padding = s * 0.15
    let bodyWidth = s * 0.5
    let bodyHeight = s * 0.85
    let bodyX = (s - bodyWidth) / 2
    let bodyY = (s - bodyHeight) / 2
    let cornerRadius = bodyWidth * 0.25

    // Shadow
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.05, color: CGColor(gray: 0, alpha: 0.5))

    // Body background - dark gray rounded rect
    let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
    context.addPath(bodyPath)
    context.fillPath()

    // Remove shadow for lights
    context.setShadow(offset: .zero, blur: 0, color: nil)

    // Border
    context.setStrokeColor(CGColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0))
    context.setLineWidth(s * 0.02)
    context.addPath(bodyPath)
    context.strokePath()

    // Light positions (top to bottom: red, yellow, green)
    let lightDiameter = bodyWidth * 0.55
    let lightRadius = lightDiameter / 2
    let lightX = s / 2
    let totalLightsHeight = lightDiameter * 3 + (bodyWidth * 0.15) * 2
    let startY = bodyY + (bodyHeight - totalLightsHeight) / 2 + lightRadius
    let spacing = lightDiameter + bodyWidth * 0.15

    let lights: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        // (centerY, r, g, b)
        (startY + spacing * 2, 1.0, 0.231, 0.188),   // Red (top in screen coords = bottom in CG coords)
        (startY + spacing, 1.0, 0.8, 0.0),            // Yellow
        (startY, 0.204, 0.78, 0.349),                  // Green
    ]

    for (centerY, r, g, b) in lights {
        // Glow effect
        let glowColors = [
            CGColor(red: r, green: g, blue: b, alpha: 0.6),
            CGColor(red: r, green: g, blue: b, alpha: 0.0)
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors as CFArray, locations: [0, 1]) {
            context.saveGState()
            context.addEllipse(in: CGRect(x: lightX - lightRadius * 1.4, y: centerY - lightRadius * 1.4, width: lightDiameter * 1.4, height: lightDiameter * 1.4))
            context.clip()
            context.drawRadialGradient(gradient, startCenter: CGPoint(x: lightX, y: centerY), startRadius: 0, endCenter: CGPoint(x: lightX, y: centerY), endRadius: lightRadius * 1.4, options: [])
            context.restoreGState()
        }

        // Light circle
        let lightRect = CGRect(x: lightX - lightRadius, y: centerY - lightRadius, width: lightDiameter, height: lightDiameter)
        context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1.0))
        context.fillEllipse(in: lightRect)

        // Inner highlight (glossy effect)
        let highlightRadius = lightRadius * 0.5
        let highlightY = centerY + lightRadius * 0.25
        let highlightColors = [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.4),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: highlightColors as CFArray, locations: [0, 1]) {
            context.saveGState()
            context.addEllipse(in: lightRect)
            context.clip()
            context.drawRadialGradient(gradient, startCenter: CGPoint(x: lightX, y: highlightY), startRadius: 0, endCenter: CGPoint(x: lightX, y: highlightY), endRadius: highlightRadius, options: [])
            context.restoreGState()
        }

        // Dark ring around light
        context.setStrokeColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
        context.setLineWidth(s * 0.015)
        context.strokeEllipse(in: lightRect)
    }

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, size: Int, path: String) {
    let resizedImage = NSImage(size: NSSize(width: size, height: size))
    resizedImage.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    resizedImage.unlockFocus()

    guard let tiffData = resizedImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
}

// Generate icon at multiple sizes
let iconsetPath = "/Users/fansea/ClaudeTrafficLight/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let baseImage = drawTrafficLight(size: 1024)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in sizes {
    savePNG(image: baseImage, size: size, path: "\(iconsetPath)/\(name)")
}

print("Iconset generated at \(iconsetPath)")
