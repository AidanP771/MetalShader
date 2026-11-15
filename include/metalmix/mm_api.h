/*
 * mm_api.h - The contract between mmloader.dylib and mmcore.dylib.
 *
 * The loader is patched into the game once and rarely changes. The core is
 * replaced on every build. This header is the only thing they share, so it must
 * stay small and backwards compatible:
 *
 *   - Never reorder or remove fields in mm_host_info. Only append.
 *   - Bump MM_API_VERSION when a change would break an older loader or core.
 *   - The core checks api_version and struct_size before reading any field.
 *
 * Threading: mm_core_start is called once, on the thread that loaded the
 * loader (during dyld initialisation, before main()). It must return quickly.
 */

#ifndef METALMIX_MM_API_H
#define METALMIX_MM_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Version of this contract. The core refuses to start on a mismatch. */
#define MM_API_VERSION 1u

/* Name of the function the loader looks up in the core with dlsym(). */
#define MM_CORE_ENTRY_SYMBOL "mm_core_start"

/* Subsystem for os_log, shared by loader and core so one predicate shows both:
 *   log stream --predicate 'subsystem == "io.metalmix"' --level debug
 * Change this if the project gets its own domain or GitHub organisation. */
#define MM_LOG_SUBSYSTEM "io.metalmix"

/* Folder names under ~/Library/Application Support. */
#define MM_SUPPORT_FOLDER_NAME "MetalMix"

/* Information the loader passes to the core. Every string points to storage
 * owned by the loader that stays valid for the life of the process. */
typedef struct mm_host_info {
    uint32_t api_version; /* Always MM_API_VERSION of the loader that filled it. */
    uint32_t struct_size; /* sizeof(mm_host_info) as the loader knows it. */

    const char *support_dir;       /* ~/Library/Application Support/MetalMix */
    const char *crash_marker_path; /* File the core deletes once frames are healthy. */
    const char *loader_path;       /* Full path of the loaded mmloader.dylib. */
    const char *core_path;         /* Full path of the core that was loaded. */

    int32_t is_dev_build; /* 1 if the loader is a Dev build, else 0. */
} mm_host_info;

/* What mm_core_start returns. Anything but MM_OK means the core did not install
 * any hooks and the game keeps running vanilla. */
typedef enum mm_status {
    MM_OK = 0,
    MM_ERR_API_MISMATCH = 1, /* Loader and core were built from incompatible versions. */
    MM_ERR_BAD_ARGUMENT = 2, /* host_info was NULL or too small. */
    MM_ERR_INIT_FAILED = 3,  /* The core could not set itself up; details are in the log. */
} mm_status;

/* Signature of the core's entry point. */
typedef mm_status (*mm_core_start_fn)(const mm_host_info *host_info);

#ifdef __cplusplus
}
#endif

#endif /* METALMIX_MM_API_H */
