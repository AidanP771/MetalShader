# mmloader.dylib: the only MetalMix code patched into the game.
# Keep it small and stable; every change means re-patching the game.

add_library(mmloader SHARED src/mm_loader.c)

set_target_properties(mmloader PROPERTIES
    PREFIX ""                      # mmloader.dylib, not libmmloader.dylib
    OUTPUT_NAME "mmloader"
    C_VISIBILITY_PRESET hidden
    # The game references the loader at this path (weak load command).
    INSTALL_NAME_DIR "@executable_path/../Frameworks"
    BUILD_WITH_INSTALL_NAME_DIR ON)

target_link_libraries(mmloader PRIVATE mm_common "-framework CoreGraphics")

# Apple Silicon refuses unsigned code. Sign ad hoc after every build.
add_custom_command(TARGET mmloader POST_BUILD
    COMMAND codesign --force --sign - $<TARGET_FILE:mmloader>
    COMMENT "Ad-hoc signing mmloader.dylib")
