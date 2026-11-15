/*
 * mm_loader.c - mmloader.dylib, the only MetalMix code patched into the game.
 *
 * Purpose: decide whether MetalMix should run this launch, and if so load
 * mmcore.dylib and hand over to it. See loader/README.md and the "Loading"
 * section of docs/architecture.md.
 *
 * Who calls it: dyld runs mm_loader_init (a constructor) when the game starts,
 * because the installer added a weak load command for this library to the
 * game's executable. In development it is loaded into the test host with
 * DYLD_INSERT_LIBRARIES instead.
 *
 * Threading: runs once, on the main thread, before the game's main(). It must
 * never crash and must return quickly. Every failure path logs and returns,
 * which leaves the game running vanilla.
 */

#include "metalmix/mm_api.h"

#include <CommonCrypto/CommonDigest.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <os/log.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

/* After this many launches in a row that never reached healthy frames, the
 * loader stops loading the core until the user deletes the marker file. */
static const int kCrashGuardMaxUnhealthyLaunches = 2;

enum {
    kSha256HexLength = CC_SHA256_DIGEST_LENGTH * 2,
    kHashReadChunkBytes = 64 * 1024,
};

/* Storage for everything handed to the core. These live for the whole process,
 * as mm_api.h promises. */
static char g_support_dir[PATH_MAX];
static char g_crash_marker_path[PATH_MAX];
static char g_loader_path[PATH_MAX];
static char g_core_path[PATH_MAX];
static mm_host_info g_host_info;
static os_log_t g_log;

/* ---- Small helpers ------------------------------------------------------ */

/* Joins two path parts with a slash. Returns false if the result would not fit. */
static bool join_path(char *out, size_t out_size, const char *first, const char *second) {
    int written = snprintf(out, out_size, "%s/%s", first, second);
    return written > 0 && (size_t)written < out_size;
}

static bool file_exists(const char *path) {
    struct stat info;
    return stat(path, &info) == 0;
}

/* Copies a string into a fixed buffer. Returns false if it would not fit. */
static bool copy_string(char *out, size_t out_size, const char *text) {
    int written = snprintf(out, out_size, "%s", text);
    return written >= 0 && (size_t)written < out_size;
}

/* ---- Step 0: work out where everything is ------------------------------- */

static bool resolve_paths(void) {
    const char *home = getenv("HOME");
    if (home == NULL || home[0] == '\0') {
        os_log_error(g_log,
                     "MetalMix skipped: HOME is not set, so the MetalMix folder cannot be found.");
        return false;
    }

    char app_support[PATH_MAX];
    if (!join_path(app_support, sizeof app_support, home, "Library/Application Support") ||
        !join_path(g_support_dir, sizeof g_support_dir, app_support, MM_SUPPORT_FOLDER_NAME) ||
        !join_path(g_crash_marker_path, sizeof g_crash_marker_path, g_support_dir, "launching")) {
        os_log_error(g_log, "MetalMix skipped: the MetalMix folder path is too long.");
        return false;
    }

    /* The loader's own path tells us where the expected core hash lives. */
    Dl_info self_info;
    if (dladdr((const void *)&resolve_paths, &self_info) == 0 || self_info.dli_fname == NULL ||
        !copy_string(g_loader_path, sizeof g_loader_path, self_info.dli_fname)) {
        os_log_error(g_log, "MetalMix skipped: could not find the loader's own path.");
        return false;
    }

    const char *core_override = MM_DEV_BUILD ? getenv("MM_CORE_PATH") : NULL;
    if (core_override != NULL && core_override[0] != '\0') {
        if (!copy_string(g_core_path, sizeof g_core_path, core_override)) {
            os_log_error(g_log, "MetalMix skipped: MM_CORE_PATH is too long.");
            return false;
        }
        os_log(g_log, "Dev build: loading core from MM_CORE_PATH %{public}s", g_core_path);
    } else if (!join_path(g_core_path, sizeof g_core_path, g_support_dir, "core/mmcore.dylib")) {
        os_log_error(g_log, "MetalMix skipped: the core path is too long.");
        return false;
    }

    /* Make sure the MetalMix folder exists so the crash marker can be written.
     * Its parent (Application Support) always exists for a logged-in user. */
    if (mkdir(g_support_dir, 0755) != 0 && errno != EEXIST) {
        os_log_error(g_log, "MetalMix skipped: could not create %{public}s (errno %d).",
                     g_support_dir, errno);
        return false;
    }
    return true;
}

/* ---- Step 1: kill switch ------------------------------------------------ */

static bool kill_switch_engaged(void) {
    const char *disable_env = getenv("MM_DISABLE");
    if (disable_env != NULL && strcmp(disable_env, "1") == 0) {
        os_log(g_log, "MetalMix skipped: MM_DISABLE=1 is set.");
        return true;
    }

    char disabled_file[PATH_MAX];
    if (join_path(disabled_file, sizeof disabled_file, g_support_dir, "DISABLED") &&
        file_exists(disabled_file)) {
        os_log(g_log, "MetalMix skipped: %{public}s exists. Delete it to turn MetalMix back on.",
               disabled_file);
        return true;
    }

    /* Holding Option while the game launches skips MetalMix for this launch. */
    CGEventFlags held = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
    if ((held & kCGEventFlagMaskAlternate) != 0) {
        os_log(g_log, "MetalMix skipped: Option was held at launch.");
        return true;
    }
    return false;
}

/* ---- Step 2: crash guard ------------------------------------------------ */

/* The marker file holds the number of launches that started but never reached
 * healthy frames. The core deletes it once frames are healthy. */
static bool crash_guard_allows_launch(void) {
    int unhealthy_launches = 0;
    FILE *marker = fopen(g_crash_marker_path, "r");
    if (marker != NULL) {
        if (fscanf(marker, "%d", &unhealthy_launches) != 1) {
            unhealthy_launches = 1; /* Unreadable marker: count it as one bad launch. */
        }
        fclose(marker);
    }

    if (unhealthy_launches >= kCrashGuardMaxUnhealthyLaunches) {
        os_log_error(g_log,
                     "MetalMix skipped: the last %d launches never reached healthy frames. "
                     "Delete %{public}s to try again.",
                     unhealthy_launches, g_crash_marker_path);
        return false;
    }

    marker = fopen(g_crash_marker_path, "w");
    if (marker == NULL) {
        /* Not fatal: MetalMix still runs, it just has no crash guard this launch. */
        os_log_error(g_log, "Could not write the crash marker %{public}s (errno %d).",
                     g_crash_marker_path, errno);
        return true;
    }
    fprintf(marker, "%d\n", unhealthy_launches + 1);
    fclose(marker);
    return true;
}

/* ---- Step 3: core integrity --------------------------------------------- */

#if !MM_DEV_BUILD
static bool sha256_file_hex(const char *path, char out_hex[kSha256HexLength + 1]) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return false;
    }

    static unsigned char chunk[kHashReadChunkBytes];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    size_t bytes_read = 0;
    while ((bytes_read = fread(chunk, 1, sizeof chunk, file)) > 0) {
        CC_SHA256_Update(&context, chunk, (CC_LONG)bytes_read);
    }
    bool read_ok = ferror(file) == 0;
    fclose(file);

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        snprintf(out_hex + (size_t)i * 2, 3, "%02x", digest[i]);
    }
    return read_ok;
}
#endif

/* Release builds only load a core whose hash matches the one the installer
 * wrote next to the loader, inside the game bundle. App Management protection
 * stops other apps rewriting files in the bundle, so a dylib planted in the
 * user-writable MetalMix folder cannot get itself loaded into the game. */
static bool core_hash_matches(void) {
#if MM_DEV_BUILD
    os_log(g_log, "Dev build: skipping the core hash check. Never ship a Dev loader.");
    return true;
#else
    char loader_dir[PATH_MAX];
    if (!copy_string(loader_dir, sizeof loader_dir, g_loader_path)) {
        return false;
    }
    char *last_slash = strrchr(loader_dir, '/');
    if (last_slash == NULL) {
        os_log_error(g_log, "MetalMix skipped: unexpected loader path %{public}s.", g_loader_path);
        return false;
    }
    *last_slash = '\0';

    char expected_path[PATH_MAX];
    char expected_hex[kSha256HexLength + 1] = {0};
    FILE *expected_file = NULL;
    if (!join_path(expected_path, sizeof expected_path, loader_dir, "mmcore.sha256") ||
        (expected_file = fopen(expected_path, "r")) == NULL) {
        os_log_error(g_log, "MetalMix skipped: no expected core hash at %{public}s.",
                     expected_path);
        return false;
    }
    size_t expected_length = fread(expected_hex, 1, kSha256HexLength, expected_file);
    fclose(expected_file);

    char actual_hex[kSha256HexLength + 1] = {0};
    if (expected_length != kSha256HexLength || !sha256_file_hex(g_core_path, actual_hex)) {
        os_log_error(g_log, "MetalMix skipped: could not read the core or its expected hash.");
        return false;
    }
    if (strncasecmp(expected_hex, actual_hex, kSha256HexLength) != 0) {
        os_log_error(g_log,
                     "MetalMix skipped: %{public}s does not match the hash the installer recorded. "
                     "Reinstall MetalMix.",
                     g_core_path);
        return false;
    }
    return true;
#endif
}

/* ---- Step 4: load the core ---------------------------------------------- */

static void load_core(void) {
    if (!file_exists(g_core_path)) {
        os_log(g_log, "MetalMix skipped: no core installed at %{public}s.", g_core_path);
        return;
    }

    void *core = dlopen(g_core_path, RTLD_NOW | RTLD_LOCAL);
    if (core == NULL) {
        const char *reason = dlerror();
        os_log_error(g_log, "MetalMix skipped: could not load the core: %{public}s",
                     reason != NULL ? reason : "unknown error");
        return;
    }

    /* memcpy avoids the object-to-function pointer cast that ISO C disallows. */
    void *symbol = dlsym(core, MM_CORE_ENTRY_SYMBOL);
    if (symbol == NULL) {
        os_log_error(g_log, "MetalMix skipped: the core has no %{public}s function.",
                     MM_CORE_ENTRY_SYMBOL);
        return;
    }
    mm_core_start_fn core_start = NULL;
    memcpy(&core_start, &symbol, sizeof core_start);

    g_host_info = (mm_host_info){
        .api_version = MM_API_VERSION,
        .struct_size = (uint32_t)sizeof(mm_host_info),
        .support_dir = g_support_dir,
        .crash_marker_path = g_crash_marker_path,
        .loader_path = g_loader_path,
        .core_path = g_core_path,
        .is_dev_build = MM_DEV_BUILD,
    };

    mm_status status = core_start(&g_host_info);
    if (status != MM_OK) {
        /* The core may have partly set itself up, so it is never unloaded. */
        os_log_error(g_log, "The core did not start (status %d). The game runs without MetalMix.",
                     (int)status);
        return;
    }
    os_log(g_log, "MetalMix core started from %{public}s", g_core_path);
}

/* ---- Entry point -------------------------------------------------------- */

__attribute__((constructor)) static void mm_loader_init(void) {
    g_log = os_log_create(MM_LOG_SUBSYSTEM, "loader");
    os_log(g_log, "mmloader %{public}s starting (%{public}s build).", MM_VERSION_STRING,
           MM_DEV_BUILD ? "dev" : "release");

    if (!resolve_paths() || kill_switch_engaged() || !crash_guard_allows_launch() ||
        !core_hash_matches()) {
        return;
    }
    load_core();
}
