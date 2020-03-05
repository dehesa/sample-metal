/// Namespace for main app window and main functionality.
enum App {
    /// The application name (displayed to the user as the app title).
    static let name = String(cString: AppInfo.name)
    /// The application bundle identifier.
    static let bundleIdentifier = String(cString: AppInfo.identifier)
    /// The app's version (major, minor, bug)
    static let version = String(cString: AppInfo.version)
    /// The app's build number.
    static let build = Int(AppInfo.build)
}
