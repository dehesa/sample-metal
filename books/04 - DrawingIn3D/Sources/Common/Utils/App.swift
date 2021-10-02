/// Namespace for main app window and main functionality.
enum App {
  /// The application name (displayed to the user as the app title).
  static var name: String { String(cString: AppInfo.name) }
  /// The application bundle identifier.
  static var bundleIdentifier: String { String(cString: AppInfo.identifier) }
  /// The app's version (major, minor, bug)
  static var version: String { String(cString: AppInfo.version) }
  /// The app's build number.
  static var build: Int { Int(AppInfo.build) }
}
