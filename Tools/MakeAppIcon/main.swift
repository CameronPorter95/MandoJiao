import AppKit
import CoreText
import Foundation

// Renders the three MandoJiao app icon variants at 1024x1024.
//
// Run from the repository root:
//   swift Tools/MakeAppIcon/main.swift MandoJiao/Assets.xcassets/AppIcon.appiconset
//
// Light is opaque and fills the square. Dark and tinted have transparent
// backgrounds, because the system composites its own background behind them.
// Tinted is grayscale so the system can tint it.

let side: CGFloat = 1024
let glyph = "教"
/// How much of the square the character's ink should cover.
let inkTarget: CGFloat = 600

func font(ofSize size: CGFloat) -> NSFont {
    NSFont(name: "PingFangSC-Semibold", size: size)
        ?? NSFont(name: "STHeitiSC-Medium", size: size)
        ?? NSFont.systemFont(ofSize: size, weight: .semibold)
}

/// Tight ink bounds of the glyph at a given font size, relative to the baseline.
func inkBounds(fontSize: CGFloat) -> CGRect {
    let attributed = NSAttributedString(
        string: glyph,
        attributes: [.font: font(ofSize: fontSize), .foregroundColor: NSColor.black]
    )
    let line = CTLineCreateWithAttributedString(attributed)
    return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
}

/// Font size at which the glyph's ink fills `inkTarget` on its longer edge.
let fittedFontSize: CGFloat = {
    let probe = inkBounds(fontSize: 100)
    let scale = inkTarget / max(probe.width, probe.height)
    return 100 * scale
}()

/// `opaque` drops the alpha channel entirely, which the default icon needs:
/// App Store validation rejects a primary app icon carrying transparency.
func makeContext(opaque: Bool) -> CGContext {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: alpha.rawValue
    )!
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.setShouldSmoothFonts(true)
    return context
}

func fillDiagonalGradient(_ context: CGContext, from top: CGColor, to bottom: CGColor) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [top, bottom] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: side * 0.12, y: side),
        end: CGPoint(x: side * 0.88, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

func draw(glyphColor: CGColor, into context: CGContext) {
    let attributed = NSAttributedString(
        string: glyph,
        attributes: [
            .font: font(ofSize: fittedFontSize),
            .foregroundColor: NSColor(cgColor: glyphColor)!
        ]
    )
    let line = CTLineCreateWithAttributedString(attributed)
    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    // Centre on the ink rather than the em box, so the character sits
    // optically centred instead of riding high.
    context.textPosition = CGPoint(
        x: (side - ink.width) / 2 - ink.minX,
        y: (side - ink.height) / 2 - ink.minY
    )
    CTLineDraw(line, context)
}

func write(_ context: CGContext, to path: String) {
    guard let image = context.makeImage() else {
        fatalError("could not make an image for \(path)")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: side, height: side)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("could not encode \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func rgb(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// Light: warm gradient matching Theme.accent, white character, no transparency.
do {
    let context = makeContext(opaque: true)
    fillDiagonalGradient(context, from: rgb(1.0, 0.71, 0.29), to: rgb(0.89, 0.39, 0.03))
    draw(glyphColor: rgb(1, 1, 1), into: context)
    write(context, to: "\(outputDirectory)/AppIcon-light.png")
}

// Dark: transparent, character in the accent orange so it reads against the
// dark background the system supplies.
do {
    let context = makeContext(opaque: false)
    draw(glyphColor: rgb(1.0, 0.60, 0.20), into: context)
    write(context, to: "\(outputDirectory)/AppIcon-dark.png")
}

// Tinted: transparent and grayscale, so the system's tint drives the colour.
do {
    let context = makeContext(opaque: false)
    draw(glyphColor: rgb(0.92, 0.92, 0.92), into: context)
    write(context, to: "\(outputDirectory)/AppIcon-tinted.png")
}

print("glyph font size \(Int(fittedFontSize.rounded())), ink \(Int(inkBounds(fontSize: fittedFontSize).width.rounded()))x\(Int(inkBounds(fontSize: fittedFontSize).height.rounded()))")
