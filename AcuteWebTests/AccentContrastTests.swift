import XCTest
import UIKit
@testable import AcuteWeb

final class AccentContrastTests: XCTestCase {
    @MainActor
    func testAccentTextHasSufficientContrastOnNativeSurfaces() throws {
        let styles: [UIUserInterfaceStyle] = [.light, .dark]
        let contrasts: [UIAccessibilityContrast] = [.normal, .high]
        for style in styles {
            for contrast in contrasts {
                let traits = UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(accessibilityContrast: contrast)
                ])
                let accent = try XCTUnwrap(UIColor(named: "AccentColor", in: .main, compatibleWith: traits))
                    .resolvedColor(with: traits)
                for surface in [UIColor.systemBackground, .secondarySystemBackground,
                                .systemGroupedBackground, .secondarySystemGroupedBackground,
                                .tertiarySystemGroupedBackground] {
                    let background = surface.resolvedColor(with: traits)
                    let foregroundLuminance = try luminance(accent)
                    let backgroundLuminance = try luminance(background)
                    let ratio = (max(foregroundLuminance, backgroundLuminance) + 0.05)
                        / (min(foregroundLuminance, backgroundLuminance) + 0.05)
                    XCTAssertGreaterThanOrEqual(ratio, 4.5,
                        "Accent contrast \(ratio), style \(style.rawValue), contrast \(contrast.rawValue)")
                }
            }
        }
    }

    private func luminance(_ color: UIColor) throws -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
        func linear(_ value: CGFloat) -> Double {
            let channel = Double(value)
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
