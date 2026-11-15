/*
 * mm_core.mm - Entry point of mmcore.dylib.
 *
 * Purpose: validate what the loader passed in, remember it, install the Metal
 * hooks, and own the crash-guard "healthy frames" counter.
 *
 * Who calls it: mmloader.dylib calls mm_core_start once, via dlsym, before the
 * game's main(). MMCoreReportHealthyFrame is called by the present hook.
 *
 * Threading: mm_core_start runs on the main thread during dyld initialisation
 * and must return quickly. MMCoreReportHealthyFrame runs on the game's render
 * thread and only does an atomic add; the file delete happens on a background
 * queue.
 */

#include "metalmix/mm_api.h"

#import <Foundation/Foundation.h>

#include <atomic>
#include <cerrno>
#include <cstdint>
#include <string>
#include <unistd.h>

#import "MMCore.h"
#import "hooks/MMHooks.h"
#import "log/MMLog.h"

namespace {

/* Frames that must be presented before this launch counts as healthy. About
 * five seconds at 60 fps: past loading, into real rendering. */
constexpr uint64_t kCrashGuardHealthyFrames = 300;

std::string g_supportDirectory;
std::string g_crashMarkerPath;
bool g_isDevBuild = false;

std::atomic<uint64_t> g_presentedFrames{0};
std::atomic<bool> g_crashMarkerCleared{false};

} // namespace

namespace mm {

const std::string &SupportDirectory() {
    return g_supportDirectory;
}

bool IsDevBuild() {
    return g_isDevBuild;
}

} // namespace mm

void MMCoreReportHealthyFrame(void) {
    const uint64_t frames = g_presentedFrames.fetch_add(1, std::memory_order_relaxed) + 1;
    if (frames < kCrashGuardHealthyFrames || g_crashMarkerCleared.exchange(true)) {
        return;
    }

    // Deleting a file is quick, but the render thread never does file I/O.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (unlink(g_crashMarkerPath.c_str()) == 0 || errno == ENOENT) {
            MMLogInfo("Launch is healthy after %llu frames; crash marker cleared.",
                      (unsigned long long)kCrashGuardHealthyFrames);
        } else {
            MMLogError("Could not delete crash marker %{public}s (errno %d).",
                       g_crashMarkerPath.c_str(), errno);
        }
    });
}

extern "C" __attribute__((visibility("default"))) mm_status
mm_core_start(const mm_host_info *hostInfo) {
    if (hostInfo == nullptr || hostInfo->struct_size < sizeof(mm_host_info)) {
        MMLogError("mm_core_start was given missing or too-small host info.");
        return MM_ERR_BAD_ARGUMENT;
    }
    if (hostInfo->api_version != MM_API_VERSION) {
        MMLogError("Loader API version %u does not match core API version %u. "
                   "Reinstall MetalMix so both come from the same release.",
                   hostInfo->api_version, MM_API_VERSION);
        return MM_ERR_API_MISMATCH;
    }

    g_supportDirectory = hostInfo->support_dir;
    g_crashMarkerPath = hostInfo->crash_marker_path;
    g_isDevBuild = hostInfo->is_dev_build != 0;

    MMLogInfo("mmcore %{public}s starting (%{public}s build), support folder %{public}s",
              MM_VERSION_STRING, g_isDevBuild ? "dev" : "release", g_supportDirectory.c_str());

    @try {
        if (!MMHooksInstall()) {
            MMLogError("Hooks were not installed; the game runs without MetalMix.");
            return MM_ERR_INIT_FAILED;
        }
    } @catch (NSException *exception) {
        MMLogError("Exception while installing hooks: %{public}@", exception.reason);
        return MM_ERR_INIT_FAILED;
    }

    return MM_OK;
}
