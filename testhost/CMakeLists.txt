# testhost.app: a small Metal app that stands in for The Sims 4 during
# development. See testhost/README.md.

add_executable(testhost MACOSX_BUNDLE src/main.mm)

set_target_properties(testhost PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "io.metalmix.testhost"
    MACOSX_BUNDLE_BUNDLE_NAME "MetalMix Test Host"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}")

target_compile_options(testhost PRIVATE -fobjc-arc)
target_link_libraries(testhost PRIVATE
    mm_common
    "-framework Cocoa"
    "-framework Metal"
    "-framework MetalKit"
    "-framework QuartzCore")

# codesign refuses a bundle that carries extended attributes ("resource fork,
# Finder information, or similar detritus not allowed"). iCloud Drive and other
# file providers add com.apple.FinderInfo to new folders, which happens when the
# checkout lives in a synced ~/Documents. Clear them right before signing.
# Use Apple's xattr by full path: a Python "xattr" earlier on PATH has no -r.
set(MM_XATTR_EXECUTABLE /usr/bin/xattr)

if(MM_TESTHOST_HARDENED)
    # Signed like the game: hardened runtime with library validation on. Used to
    # test the patch and re-sign path (scripts/m0-resign.sh --app ...) without
    # the game. DYLD_INSERT_LIBRARIES does not work on this variant.
    add_custom_command(TARGET testhost POST_BUILD
        COMMAND ${MM_XATTR_EXECUTABLE} -cr $<TARGET_BUNDLE_DIR:testhost>
        COMMAND codesign --force --sign - --options runtime
                --entitlements ${CMAKE_CURRENT_SOURCE_DIR}/testhost.entitlements
                $<TARGET_BUNDLE_DIR:testhost>
        COMMENT "Signing testhost.app with the hardened runtime")
else()
    # Plain ad-hoc signature so scripts/inject-testhost.sh can use
    # DYLD_INSERT_LIBRARIES during day-to-day development.
    add_custom_command(TARGET testhost POST_BUILD
        COMMAND ${MM_XATTR_EXECUTABLE} -cr $<TARGET_BUNDLE_DIR:testhost>
        COMMAND codesign --force --sign - $<TARGET_BUNDLE_DIR:testhost>
        COMMENT "Ad-hoc signing testhost.app")
endif()
