import UIKit

enum BrandIconService {
    /// Alternate icon keys bundled in this app version (must match AppIcon-{key} asset names).
    /// Add new client icons here when you ship a monthly build.
    static let bundledAlternateIconKeys: Set<String> = ["fbcvr"]

    @MainActor
    static func applyAlternateIcon(key: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let normalized = key?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target: String? = {
            guard let normalized, !normalized.isEmpty,
                  bundledAlternateIconKeys.contains(normalized) else {
                return nil
            }
            return normalized
        }()

        if UIApplication.shared.alternateIconName == target { return }

        UIApplication.shared.setAlternateIconName(target) { error in
            if let error {
                print("Alternate icon error: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    static func resetToDefaultIcon() {
        applyAlternateIcon(key: nil)
    }
}
