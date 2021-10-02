#ifndef AppInfo_h
#define AppInfo_h

struct AppBuildInformation {
  /// The framework's given name.
  char const* const _Nonnull name;
  /// The framework's bundle identifier
  char const* const _Nonnull identifier;
  /// The framework's version (major, minor, bug)
  char const* const _Nonnull version;
  /// The framework's build number.
  unsigned short build;
};

extern struct AppBuildInformation AppInfo;

#endif
