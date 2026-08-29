import UIKit

/// 생성된 이미지를 태그(EPD_TEST_01 펌웨어)가 그대로 그릴 수 있는 4색(흰/노랑/빨강/검정)
/// 8000바이트 포맷으로 변환합니다. 파이썬 쪽 ble_epd.py의 _dither/_pack과 정확히 동일한
/// 알고리즘이어야 태그에서 같은 픽셀이 나옵니다.
enum EPDImagePacker {
    static let width = 250
    static let height = 122
    static let ramHeight = 128
    static let bytesPerColumn = ramHeight / 4 // 32
    static let imageSize = width * bytesPerColumn // 8000

    // white=0, yellow=1, red=2, black=3 -- 순서가 펌웨어/파이썬과 반드시 일치해야 함
    private static let palette: [(r: Float, g: Float, b: Float)] = [
        (255, 255, 255),
        (255, 255, 0),
        (255, 0, 0),
        (0, 0, 0),
    ]

    static func pack(_ image: UIImage) -> Data? {
        guard var rgb = resizedRGBBuffer(image, width: width, height: height) else { return nil }

        var colorMap = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 3
                let oldR = rgb[i], oldG = rgb[i + 1], oldB = rgb[i + 2]

                var bestIndex = 0
                var bestDistance = Float.greatestFiniteMagnitude
                for (index, p) in palette.enumerated() {
                    let dr = oldR - p.r, dg = oldG - p.g, db = oldB - p.b
                    let distance = dr * dr + dg * dg + db * db
                    if distance < bestDistance {
                        bestDistance = distance
                        bestIndex = index
                    }
                }
                colorMap[y * width + x] = UInt8(bestIndex)

                let chosen = palette[bestIndex]
                let errR = oldR - chosen.r
                let errG = oldG - chosen.g
                let errB = oldB - chosen.b

                func diffuse(_ xx: Int, _ yy: Int, _ factor: Float) {
                    guard xx >= 0, xx < width, yy >= 0, yy < height else { return }
                    let j = (yy * width + xx) * 3
                    rgb[j] = min(255, max(0, rgb[j] + errR * factor))
                    rgb[j + 1] = min(255, max(0, rgb[j + 1] + errG * factor))
                    rgb[j + 2] = min(255, max(0, rgb[j + 2] + errB * factor))
                }

                diffuse(x + 1, y, 7.0 / 16.0)
                diffuse(x - 1, y + 1, 3.0 / 16.0)
                diffuse(x, y + 1, 5.0 / 16.0)
                diffuse(x + 1, y + 1, 1.0 / 16.0)
            }
        }

        var packed = Data(capacity: imageSize)
        for x in stride(from: width - 1, through: 0, by: -1) {
            for byteY in 0..<bytesPerColumn {
                var value: UInt8 = 0
                for i in 0..<4 {
                    let y = byteY * 4 + i
                    let color: UInt8 = y < height ? (colorMap[y * width + x] & 0x03) : 0
                    value |= color << (6 - i * 2)
                }
                packed.append(value)
            }
        }
        return packed
    }

    private static func resizedRGBBuffer(_ image: UIImage, width: Int, height: Int) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rgb = [Float](repeating: 0, count: width * height * 3)
        for i in 0..<(width * height) {
            rgb[i * 3] = Float(pixels[i * 4])
            rgb[i * 3 + 1] = Float(pixels[i * 4 + 1])
            rgb[i * 3 + 2] = Float(pixels[i * 4 + 2])
        }
        return rgb
    }
}
