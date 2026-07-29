#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let columns = 8
private let sourceRows = 10
private let outputRows = 11
private let cellWidth = 192
private let cellHeight = 208

private struct PixelComponent {
    var pixels: [Int]
    var minX: Int
    var maxX: Int
    var minY: Int
    var maxY: Int
}

private func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
    let unit = max(0, min(1, (value - low) / (high - low)))
    return unit * unit * (3 - 2 * unit)
}

private func loadImage(at url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(
            domain: "SmileCodexPet",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to decode \(url.path)"]
        )
    }
    return image
}

private func removeGreen(from image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw NSError(domain: "SmileCodexPet", code: 2)
    }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    for offset in stride(from: 0, to: pixels.count, by: 4) {
        let red = Double(pixels[offset])
        let green = Double(pixels[offset + 1])
        let blue = Double(pixels[offset + 2])
        let dominance = green - max(red, blue)
        guard green > 70, dominance > 8 else { continue }

        let distance = sqrt(
            red * red
                + (255 - green) * (255 - green)
                + blue * blue
        )
        let alpha = smoothstep(18, 190, distance)
        let edgeGreen = max(red, blue)
        pixels[offset] = UInt8(max(0, min(255, red * alpha)))
        pixels[offset + 1] = UInt8(max(0, min(255, edgeGreen * alpha)))
        pixels[offset + 2] = UInt8(max(0, min(255, blue * alpha)))
        pixels[offset + 3] = UInt8(max(0, min(255, 255 * alpha)))
    }

    guard let result = context.makeImage() else {
        throw NSError(domain: "SmileCodexPet", code: 3)
    }
    return result
}

private func sourceFrame(
    image: CGImage,
    column: Int,
    row: Int
) throws -> CGImage {
    let verticalSafetyMargin = 22
    let left = Int((Double(column) * Double(image.width) / Double(columns)).rounded())
    let right = Int((Double(column + 1) * Double(image.width) / Double(columns)).rounded())
    let nominalTop = Int(
        (Double(row) * Double(image.height) / Double(sourceRows)).rounded()
    )
    let nominalBottom = Int(
        (Double(row + 1) * Double(image.height) / Double(sourceRows)).rounded()
    )
    let top = max(0, nominalTop - verticalSafetyMargin)
    let bottom = min(image.height, nominalBottom + verticalSafetyMargin)
    let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
    guard let frame = image.cropping(to: rect) else {
        throw NSError(domain: "SmileCodexPet", code: 4)
    }
    return frame
}

private func cleanFrame(_ image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw NSError(domain: "SmileCodexPet", code: 5)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var visited = [Bool](repeating: false, count: width * height)
    var components: [PixelComponent] = []
    let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    for start in 0..<(width * height) {
        guard !visited[start], pixels[start * 4 + 3] > 8 else { continue }
        visited[start] = true
        var queue = [start]
        var head = 0
        var component = PixelComponent(
            pixels: [],
            minX: start % width,
            maxX: start % width,
            minY: start / width,
            maxY: start / width
        )
        while head < queue.count {
            let pixel = queue[head]
            head += 1
            component.pixels.append(pixel)
            let x = pixel % width
            let y = pixel / width
            component.minX = min(component.minX, x)
            component.maxX = max(component.maxX, x)
            component.minY = min(component.minY, y)
            component.maxY = max(component.maxY, y)

            for (dx, dy) in neighbors {
                let nextX = x + dx
                let nextY = y + dy
                guard nextX >= 0, nextX < width,
                      nextY >= 0, nextY < height else {
                    continue
                }
                let next = nextY * width + nextX
                guard !visited[next], pixels[next * 4 + 3] > 8 else { continue }
                visited[next] = true
                queue.append(next)
            }
        }
        components.append(component)
    }

    guard let main = components.max(by: { $0.pixels.count < $1.pixels.count }) else {
        throw NSError(domain: "SmileCodexPet", code: 6)
    }

    let mainWidth = max(1, main.maxX - main.minX + 1)
    let mainHeight = max(1, main.maxY - main.minY + 1)
    let allowedMinX = main.minX - mainWidth / 3
    let allowedMaxX = main.maxX + mainWidth / 3
    let allowedMinY = main.minY - mainHeight / 3
    let allowedMaxY = main.maxY + mainHeight / 3
    let minimumDetailSize = max(4, main.pixels.count / 80)
    var keep = [Bool](repeating: false, count: width * height)

    for component in components {
        let centerX = (component.minX + component.maxX) / 2
        let centerY = (component.minY + component.maxY) / 2
        let touchesEdge = component.minX == 0 || component.maxX == width - 1
            || component.minY == 0 || component.maxY == height - 1
        let nearMain = centerX >= allowedMinX && centerX <= allowedMaxX
            && centerY >= allowedMinY && centerY <= allowedMaxY
        let shouldKeep = component.pixels.count == main.pixels.count
            || (!touchesEdge && nearMain && component.pixels.count >= minimumDetailSize)
        if shouldKeep {
            for pixel in component.pixels {
                keep[pixel] = true
            }
        }
    }

    for pixel in keep.indices where !keep[pixel] {
        pixels[pixel * 4] = 0
        pixels[pixel * 4 + 1] = 0
        pixels[pixel * 4 + 2] = 0
        pixels[pixel * 4 + 3] = 0
    }

    guard let result = context.makeImage() else {
        throw NSError(domain: "SmileCodexPet", code: 7)
    }
    return result
}

private func buildSheet(from source: CGImage) throws -> CGImage {
    let outputWidth = columns * cellWidth
    let outputHeight = outputRows * cellHeight
    guard let context = CGContext(
        data: nil,
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bytesPerRow: outputWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw NSError(domain: "SmileCodexPet", code: 10)
    }

    context.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
    context.interpolationQuality = .high

    for outputRow in 0..<outputRows {
        let sourceRow: Int
        if outputRow < 9 {
            sourceRow = outputRow
        } else if outputRow == 9 {
            // Codex v2 reserves an extra animation row; a calm idle loop is a safe fallback.
            sourceRow = 0
        } else {
            sourceRow = 9
        }

        for outputColumn in 0..<columns {
            let frame = try cleanFrame(
                sourceFrame(image: source, column: outputColumn, row: sourceRow)
            )
            let destination = CGRect(
                x: outputColumn * cellWidth,
                y: (outputRows - 1 - outputRow) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
            context.draw(frame, in: destination)
        }
    }

    guard let result = context.makeImage() else {
        throw NSError(domain: "SmileCodexPet", code: 11)
    }
    return result
}

private func savePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "SmileCodexPet", code: 12)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "SmileCodexPet", code: 13)
    }
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("Usage: make_codex_pet.swift <green-screen.png> <spritesheet.png>\n".utf8)
    )
    exit(2)
}

do {
    let input = URL(fileURLWithPath: CommandLine.arguments[1])
    let output = URL(fileURLWithPath: CommandLine.arguments[2])
    try FileManager.default.createDirectory(
        at: output.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let source = try removeGreen(from: loadImage(at: input))
    try savePNG(try buildSheet(from: source), to: output)
    print("Built Codex pet spritesheet: \(output.path)")
} catch {
    FileHandle.standardError.write(Data("Failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
