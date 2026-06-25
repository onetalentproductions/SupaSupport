import Foundation

enum AppConfig {
    static let appName = "SupaSupport"
    static let siteURL = URL(string: "https://supasupport.net")!
    static let setupURL = URL(string: "https://supasupport.net/setup")!

    /// Web OAuth client ID from Google Cloud Console (NOT the iOS client ID).
    static let googleWebClientID = "257187187765-megc0kba9kpc1larhrp872pvvtqcnutu.apps.googleusercontent.com"
}
