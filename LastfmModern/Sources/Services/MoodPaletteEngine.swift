import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct DashboardMoodPalette: Equatable {
    let gradientStart: NSColor
    let gradientEnd: NSColor
    let glowPrimary: NSColor
    let glowSecondary: NSColor
    let accent: NSColor

    static let fallback = DashboardMoodPalette(
        gradientStart: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.22, alpha: 1),
        gradientEnd: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1),
        glowPrimary: NSColor(calibratedRed: 0.35, green: 0.56, blue: 0.92, alpha: 1),
        glowSecondary: NSColor(calibratedRed: 0.88, green: 0.46, blue: 0.24, alpha: 1),
        accent: NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.32, alpha: 1)
    )
}

enum MoodPaletteEngine {
    /*
     Mood mapping note:
     This engine does not claim one-to-one "genre = color" science. The
     literature is stronger on broad color-emotion and valence/arousal
     associations than on direct genre palettes, so the mapping below uses
     Last.fm tags as mood proxies and then applies color families that are
     directionally consistent with that research.

     In practice:
     - cool / lower-saturation families are used for calmer, lower-arousal tags
     - warm / higher-saturation families are used for more energetic tags
     - artwork dominant color is blended back in so the result remains grounded
       in the currently playing release instead of feeling purely rule-based

     APA references for further reading:
     - Jonauskaite, D., Abu-Akel, A., Dael, N., Oberfeld, D., Abdel-Khalek, A. M.,
       Al-Rasheed, A., ... & Mohr, C. (2020). Universal patterns in color-emotion
       associations are further shaped by linguistic and geographic proximity.
       Psychological Science, 31(10), 1245-1260.
       https://pubmed.ncbi.nlm.nih.gov/32900287/
     - Palmer, S. E., & Schloss, K. B. (2010). An ecological valence theory of
       human color preference. Proceedings of the National Academy of Sciences,
       107(19), 8877-8882. https://pubmed.ncbi.nlm.nih.gov/20421475/
     - Valdez, P., & Mehrabian, A. (1994). Effects of color on emotions.
       Journal of Experimental Psychology: General, 123(4), 394-409.
       https://pubmed.ncbi.nlm.nih.gov/7996122/
    */
    // These grouped tags translate the broad color-emotion heuristic into
    // concrete palette families: cooler/desaturated groups skew calmer or
    // lower-arousal, while warmer/more saturated groups skew more energetic.
    private static let groups: [(tags: Set<String>, palette: DashboardMoodPalette)] = [
        (
            tags: ["ambient", "dream pop", "shoegaze", "dreampop", "chillwave", "ethereal"],
            palette: DashboardMoodPalette(
                gradientStart: NSColor(calibratedRed: 0.19, green: 0.24, blue: 0.36, alpha: 1),
                gradientEnd: NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.24, alpha: 1),
                glowPrimary: NSColor(calibratedRed: 0.49, green: 0.61, blue: 0.90, alpha: 1),
                glowSecondary: NSColor(calibratedRed: 0.67, green: 0.58, blue: 0.86, alpha: 1),
                accent: NSColor(calibratedRed: 0.74, green: 0.67, blue: 0.93, alpha: 1)
            )
        ),
        (
            tags: ["electronic", "techno", "idm", "electro", "synthwave", "electronica"],
            palette: DashboardMoodPalette(
                gradientStart: NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.25, alpha: 1),
                gradientEnd: NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.15, alpha: 1),
                glowPrimary: NSColor(calibratedRed: 0.21, green: 0.77, blue: 0.92, alpha: 1),
                glowSecondary: NSColor(calibratedRed: 0.44, green: 0.58, blue: 0.72, alpha: 1),
                accent: NSColor(calibratedRed: 0.31, green: 0.87, blue: 0.89, alpha: 1)
            )
        ),
        (
            tags: ["jazz", "soul", "funk", "rnb", "mpb", "neo soul"],
            palette: DashboardMoodPalette(
                gradientStart: NSColor(calibratedRed: 0.24, green: 0.18, blue: 0.11, alpha: 1),
                gradientEnd: NSColor(calibratedRed: 0.12, green: 0.09, blue: 0.06, alpha: 1),
                glowPrimary: NSColor(calibratedRed: 0.88, green: 0.66, blue: 0.30, alpha: 1),
                glowSecondary: NSColor(calibratedRed: 0.78, green: 0.54, blue: 0.35, alpha: 1),
                accent: NSColor(calibratedRed: 0.95, green: 0.79, blue: 0.52, alpha: 1)
            )
        ),
        (
            tags: ["metal", "industrial", "noise", "drone", "hardcore", "doom"],
            palette: DashboardMoodPalette(
                gradientStart: NSColor(calibratedRed: 0.14, green: 0.13, blue: 0.16, alpha: 1),
                gradientEnd: NSColor(calibratedRed: 0.06, green: 0.05, blue: 0.07, alpha: 1),
                glowPrimary: NSColor(calibratedRed: 0.58, green: 0.18, blue: 0.24, alpha: 1),
                glowSecondary: NSColor(calibratedRed: 0.30, green: 0.34, blue: 0.40, alpha: 1),
                accent: NSColor(calibratedRed: 0.75, green: 0.24, blue: 0.31, alpha: 1)
            )
        ),
        (
            tags: ["folk", "acoustic", "singer-songwriter", "americana", "country", "indie folk"],
            palette: DashboardMoodPalette(
                gradientStart: NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.13, alpha: 1),
                gradientEnd: NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.08, alpha: 1),
                glowPrimary: NSColor(calibratedRed: 0.49, green: 0.59, blue: 0.34, alpha: 1),
                glowSecondary: NSColor(calibratedRed: 0.61, green: 0.46, blue: 0.30, alpha: 1),
                accent: NSColor(calibratedRed: 0.74, green: 0.64, blue: 0.43, alpha: 1)
            )
        ),
        (
            tags: ["disco", "dance", "house", "club", "nu disco", "dance pop"],
            palette: DashboardMoodPalette(
                gradientStart: NSColor(calibratedRed: 0.24, green: 0.09, blue: 0.24, alpha: 1),
                gradientEnd: NSColor(calibratedRed: 0.12, green: 0.05, blue: 0.13, alpha: 1),
                glowPrimary: NSColor(calibratedRed: 0.83, green: 0.31, blue: 0.77, alpha: 1),
                glowSecondary: NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.20, alpha: 1),
                accent: NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.35, alpha: 1)
            )
        )
    ]

    private static let artworkSampler = ArtworkColorSampler()

    static func resolvePalette(
        trackTags: [String],
        artistTags: [String],
        artworkURL: String?
    ) async -> DashboardMoodPalette {
        let tags = normalizedMoodTags(trackTags: trackTags, artistTags: artistTags)
        let base = tagDrivenPalette(from: tags) ?? .fallback
        guard let artworkURL, let url = URL(string: artworkURL),
              let dominant = await artworkSampler.dominantColor(for: url) else {
            return base
        }
        return blend(base: base, artwork: dominant)
    }

    private static func normalizedMoodTags(trackTags: [String], artistTags: [String]) -> [String] {
        let normalizedTrack = trackTags.map(normalize)
        if normalizedTrack.count >= 2 {
            return normalizedTrack
        }
        return Array((normalizedTrack + artistTags.map(normalize)).prefix(8))
    }

    private static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func tagDrivenPalette(from tags: [String]) -> DashboardMoodPalette? {
        var bestMatchCount = 0
        var bestPalette: DashboardMoodPalette?

        for group in groups {
            let matchCount = tags.reduce(into: 0) { partial, tag in
                if group.tags.contains(tag) {
                    partial += 1
                }
            }
            if matchCount > bestMatchCount {
                bestMatchCount = matchCount
                bestPalette = group.palette
            }
        }

        return bestPalette
    }

    private static func blend(base: DashboardMoodPalette, artwork: NSColor) -> DashboardMoodPalette {
        let artwork = artwork.usingColorSpace(.deviceRGB) ?? artwork
        return DashboardMoodPalette(
            gradientStart: mix(base.gradientStart, artwork, ratio: 0.24),
            gradientEnd: mix(base.gradientEnd, artwork.blended(withFraction: 0.35, of: .black) ?? artwork, ratio: 0.14),
            glowPrimary: mix(base.glowPrimary, artwork, ratio: 0.42),
            glowSecondary: mix(base.glowSecondary, artwork, ratio: 0.26),
            accent: mix(base.accent, artwork, ratio: 0.18)
        )
    }

    private static func mix(_ lhs: NSColor, _ rhs: NSColor, ratio: CGFloat) -> NSColor {
        let a = lhs.usingColorSpace(.deviceRGB) ?? lhs
        let b = rhs.usingColorSpace(.deviceRGB) ?? rhs
        let t = max(0, min(1, ratio))
        return NSColor(
            calibratedRed: a.redComponent + ((b.redComponent - a.redComponent) * t),
            green: a.greenComponent + ((b.greenComponent - a.greenComponent) * t),
            blue: a.blueComponent + ((b.blueComponent - a.blueComponent) * t),
            alpha: 1
        )
    }
}

actor ArtworkColorSampler {
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private let areaAverage = CIFilter.areaAverage()
    private var cache: [URL: NSColor] = [:]

    func dominantColor(for url: URL) async -> NSColor? {
        if let cached = cache[url] {
            return cached
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else {
            return nil
        }

        areaAverage.inputImage = ciImage
        areaAverage.extent = ciImage.extent
        guard let outputImage = areaAverage.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let color = NSColor(
            calibratedRed: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1
        )
        cache[url] = color
        return color
    }
}
