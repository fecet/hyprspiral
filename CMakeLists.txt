cmake_minimum_required(VERSION 3.12)
project("hyprscroller"
    LANGUAGES CXX
    DESCRIPTION "Hyprland layout similar to PaperWM and niri")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(HYPRLAND REQUIRED hyprland)
pkg_check_modules(DEPS REQUIRED hyprutils hyprlang pixman-1 libdrm pangocairo)

# Diagnostic: verify which Hyprland we're building against
execute_process(
    COMMAND pkg-config --modversion hyprland
    OUTPUT_VARIABLE HYPRLAND_PKG_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE PKG_CONFIG_RESULT
)

message(STATUS "========================================")
message(STATUS "HYPRLAND BUILD VERIFICATION")
message(STATUS "========================================")

if(NOT PKG_CONFIG_RESULT EQUAL 0)
    message(FATAL_ERROR "pkg-config failed to find hyprland! Make sure hyprland-spiral is installed.")
endif()

message(STATUS "pkg-config version: ${HYPRLAND_PKG_VERSION}")
message(STATUS "Include directories: ${HYPRLAND_INCLUDE_DIRS}")

# Verify we're using hyprland-spiral (should have VCS version or be from our build)
if(HYPRLAND_PKG_VERSION MATCHES "^0\\.51\\.0$")
    message(WARNING "Using hyprland 0.51.0 without VCS info - this might not be hyprland-spiral!")
    message(WARNING "Expected version format: 0.51.0.r<commits>.<hash>.fork<commits>")
    message(WARNING "Continuing anyway, but verify build artifacts manually.")
endif()

message(STATUS "========================================")

# Note: GIT_COMMIT_HASH is provided by Hyprland's version.h
# Do NOT redefine it here, as it must match the running Hyprland's commit hash
# The version.h is automatically included through Hyprland headers

# Compile flags
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED true)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(CMAKE_CXX_FLAGS "-fno-gnu-unique")
endif()

add_library(hyprscroller SHARED
            src/main.cpp
            src/dispatchers.h
            src/dispatchers.cpp
            src/list.h
            src/overview.h
            src/overview.cpp
            src/scroller.h
            src/scroller.cpp
            src/enums.h
            src/enums.cpp
            src/common.h
            src/sizes.h
            src/sizes.cpp
            src/window.h
            src/window.cpp
            src/decorations.h
            src/decorations.cpp
            src/column.h
            src/column.cpp
            src/row.h
            src/row.cpp
            src/functions.h
            src/functions.cpp
        )

add_compile_definitions(WLR_USE_UNSTABLE)

target_include_directories(hyprscroller PRIVATE ${HYPRLAND_INCLUDE_DIRS} ${DEPS_INCLUDE_DIRS})
set_target_properties(hyprscroller PROPERTIES PREFIX "")
