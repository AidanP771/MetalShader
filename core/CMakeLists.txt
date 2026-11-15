# mmcore.dylib: everything MetalMix does inside the game.
# Lives in ~/Library/Application Support/MetalMix/core/ and is replaced freely.

add_library(mmcore SHARED
    src/mm_core.mm
    src/log/MMLog.mm
    src/hooks/MMSwizzle.mm
    src/hooks/MMHooks.mm)

set_target_properties(mmcore PROPERTIES
    PREFIX ""                       # mmcore.dylib, not libmmcore.dylib
    OUTPUT_NAME "mmcore"
    CXX_VISIBILITY_PRESET hidden    # only mm_core_start is exported
    OBJCXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON)

target_include_directories(mmcore PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_options(mmcore PRIVATE -fobjc-arc)

target_link_libraries(mmcore PRIVATE
    mm_common
    "-framework Foundation"
    "-framework Metal"
    "-framework QuartzCore"
    "-framework AppKit")

add_custom_command(TARGET mmcore POST_BUILD
    COMMAND codesign --force --sign - $<TARGET_FILE:mmcore>
    COMMENT "Ad-hoc signing mmcore.dylib")
