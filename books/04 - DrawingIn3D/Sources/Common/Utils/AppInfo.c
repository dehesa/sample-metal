#include "AppInfo.h"

//struct IGInfo const* const _Nonnull IGBundle = &info;
struct AppBuildInformation AppInfo = {
    .name = APP_BUNDLE_NAME,
    .identifier = APP_BUNDLE_ID,
    .version = APP_BUNDLE_VERSION,
    .build = APP_BUNDLE_BUILD
};
