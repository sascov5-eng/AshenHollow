import Foundation
import UIKit

@MainActor
enum SpriteResourceDiagnostic {
    static func status() -> String {
        let bundleURL = Bundle.main.bundleURL
        let directURL = bundleURL.appendingPathComponent("player_run.png")
        let fileExists = FileManager.default.fileExists(atPath: directURL.path)

        guard fileExists else {
            return "FILE MISSING"
        }

        guard let data = try? Data(contentsOf: directURL) else {
            return "FILE OK • DATA FAIL"
        }

        let byteCount = data.count
        guard let image = UIImage(data: data) else {
            return "FILE OK • DATA \(byteCount) • IMAGE FAIL"
        }

        guard image.cgImage != nil else {
            return "FILE OK • DATA \(byteCount) • IMAGE OK • CG FAIL"
        }

        return "FILE OK • DATA \(byteCount) • IMAGE OK • CG OK"
    }
}
