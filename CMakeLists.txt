# MetalMix top-level build.
#
# Targets:
#   mmloader  - loader/  tiny library patched into the game (C)
#   mmcore    - core/    hooks, runtime, overlay (Objective-C++)
#   testhost  - testhost/ stand-in Metal app for development
#   mmctl     - tools/mmctl/ control CLI (C)
#
# Use the presets in CMakePresets.json rather than configuring by hand.

cmake_minimum_required(VERSION 3.24)

# Must be set before project(). The test Mac runs macOS 15.6; do not raise this
# without checking which Macs MetalMix supports (docs/architecture.md).
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum macOS version")

project(MetalMix
    VERSION 0.1.0
    DESCRIPTION "Metal post-processing injector for The Sims 4 on macOS"
    LANGUAGES C CXX OBJC OBJCXX)

if(NOT APPLE)
    message(FATAL_ERROR "MetalMix only builds on macOS.")
endif()

option(MM_DEV_BUILD "Enable developer features: control socket, verbose logs, no core hash check" ON)
option(MM_BUILD_TESTHOST "Build the test host app" ON)
option(MM_BUILD_TOOLS "Build mmctl and other tools" ON)
option(MM_TESTHOST_HARDENED "Sign the test host with the hardened runtime, like the game" OFF)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Settings every MetalMix target shares: the public header, warnings, and the
# build-flavour macros. Link a target to mm_common to pick these up.
add_library(mm_common INTERFACE)
target_include_directories(mm_common INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_options(mm_common INTERFACE -Wall -Wextra -Wpedantic -Wno-gnu-zero-variadic-macro-arguments)
target_compile_definitions(mm_common INTERFACE
    MM_VERSION_STRING="${PROJECT_VERSION}"
    MM_DEV_BUILD=$<BOOL:${MM_DEV_BUILD}>)

add_subdirectory(loader)
add_subdirectory(core)

if(MM_BUILD_TESTHOST)
    add_subdirectory(testhost)
endif()

if(MM_BUILD_TOOLS)
    add_subdirectory(tools/mmctl)
endif()

message(STATUS "MetalMix ${PROJECT_VERSION}: dev build = ${MM_DEV_BUILD}, "
               "architectures = ${CMAKE_OSX_ARCHITECTURES}, "
               "deployment target = ${CMAKE_OSX_DEPLOYMENT_TARGET}")
