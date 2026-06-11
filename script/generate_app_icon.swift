#!/usr/bin/env swift
import AppKit
import Foundation

struct IconFile {
    let name: String
    let pixels: Int
}

let files = [
    IconFile(name: "icon_16x16.png", pixels: 16),
    IconFile(name: "icon_16x16@2x.png", pixels: 32),
    IconFile(name: "icon_32x32.png", pixels: 32),
    IconFile(name: "icon_32x32@2x.png", pixels: 64),
    IconFile(name: "icon_128x128.png", pixels: 128),
    IconFile(name: "icon_128x128@2x.png", pixels: 256),
    IconFile(name: "icon_256x256.png", pixels: 256),
    IconFile(name: "icon_256x256@2x.png", pixels: 512),
    IconFile(name: "icon_512x512.png", pixels: 512),
    IconFile(name: "icon_512x512@2x.png", pixels: 1024)
]

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate_app_icon.swift <output.iconset>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

for file in files {
    let data = try renderIcon(pixelSize: file.pixels)
    try data.write(to: outputURL.appendingPathComponent(file.name))
}

private func renderIcon(pixelSize: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError.bitmapCreationFailed
    }

    let context = NSGraphicsContext(bitmapImageRep: representation)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

    guard let cgContext = context?.cgContext else {
        throw IconError.contextCreationFailed
    }

    cgContext.scaleBy(x: CGFloat(pixelSize) / 1024.0, y: CGFloat(pixelSize) / 1024.0)
    drawClipSightIcon(in: cgContext)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncodingFailed
    }

    return data
}

private func drawClipSightIcon(in context: CGContext) {
    let outer = CGRect(x: 72, y: 72, width: 880, height: 880)
    let radius: CGFloat = 198

    context.setFillColor(NSColor.black.cgColor)
    context.addPath(CGPath(roundedRect: outer, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()

    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(12)
    context.addPath(CGPath(roundedRect: outer.insetBy(dx: 8, dy: 8), cornerWidth: radius - 6, cornerHeight: radius - 6, transform: nil))
    context.strokePath()

    let frameRect = CGRect(x: 260, y: 238, width: 504, height: 548)
    drawViewfinder(in: context, rect: frameRect)
    drawTextLines(in: context, rect: frameRect)
}

private func drawViewfinder(in context: CGContext, rect: CGRect) {
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(42)
    context.setStrokeColor(NSColor.white.cgColor)

    let cornerLength: CGFloat = 134
    let inset: CGFloat = 28

    func strokeCorner(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    strokeCorner([
        CGPoint(x: rect.minX + inset + cornerLength, y: rect.maxY - inset),
        CGPoint(x: rect.minX + inset, y: rect.maxY - inset),
        CGPoint(x: rect.minX + inset, y: rect.maxY - inset - cornerLength)
    ])
    strokeCorner([
        CGPoint(x: rect.maxX - inset - cornerLength, y: rect.maxY - inset),
        CGPoint(x: rect.maxX - inset, y: rect.maxY - inset),
        CGPoint(x: rect.maxX - inset, y: rect.maxY - inset - cornerLength)
    ])
    strokeCorner([
        CGPoint(x: rect.minX + inset + cornerLength, y: rect.minY + inset),
        CGPoint(x: rect.minX + inset, y: rect.minY + inset),
        CGPoint(x: rect.minX + inset, y: rect.minY + inset + cornerLength)
    ])
    strokeCorner([
        CGPoint(x: rect.maxX - inset - cornerLength, y: rect.minY + inset),
        CGPoint(x: rect.maxX - inset, y: rect.minY + inset),
        CGPoint(x: rect.maxX - inset, y: rect.minY + inset + cornerLength)
    ])
}

private func drawTextLines(in context: CGContext, rect: CGRect) {
    context.setFillColor(NSColor.white.cgColor)

    let lineHeight: CGFloat = 32
    let radius: CGFloat = lineHeight / 2
    let centerX = rect.midX
    let lines: [(width: CGFloat, y: CGFloat)] = [
        (210, rect.midY + 88),
        (306, rect.midY + 12),
        (246, rect.midY - 64)
    ]

    for lineSpec in lines {
        let line = CGRect(
            x: centerX - lineSpec.width / 2,
            y: lineSpec.y - lineHeight / 2,
            width: lineSpec.width,
            height: lineHeight
        )
        context.addPath(CGPath(
            roundedRect: line,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        ))
        context.fillPath()
    }
}

private enum IconError: Error {
    case bitmapCreationFailed
    case contextCreationFailed
    case pngEncodingFailed
}
