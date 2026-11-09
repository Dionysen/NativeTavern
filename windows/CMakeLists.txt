# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(native_tavern LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "native_tavern")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)
# VS 2026 / MSVC 14.5x treats <experimental/coroutine> as a hard error
# (STL1011). Several plugins still include it; silence until they migrate.
add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
# Chinese Windows defaults to code page 936; UTF-8 sources in plugins otherwise
# trigger C4819. Force UTF-8 for all MSVC targets (including plugins).
if(MSVC)
  add_compile_options(/utf-8)
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# flutter_inappwebview_windows 0.6.0 passes DEPENDS to add_custom_command(TARGET),
# which CMake 3.30+ warns about (CMP0175). Remove once pub resolves a fixed release.
set(_flutter_inappwebview_windows_cmake
  "${FLUTTER_MANAGED_DIR}/ephemeral/.plugin_symlinks/flutter_inappwebview_windows/windows/CMakeLists.txt")
if(EXISTS "${_flutter_inappwebview_windows_cmake}")
  file(READ "${_flutter_inappwebview_windows_cmake}" _flutter_inappwebview_windows_cmake_contents)
  if(_flutter_inappwebview_windows_cmake_contents MATCHES "TARGET[ \t\n\r]+[^ \t\n\r]+[ \t\n\r]+PRE_BUILD")
    string(REGEX REPLACE "[ \t]*DEPENDS \\$\\{NUGET\\}[ \t]*(\r?\n)" "\\1"
      _flutter_inappwebview_windows_cmake_contents
      "${_flutter_inappwebview_windows_cmake_contents}")
    file(WRITE "${_flutter_inappwebview_windows_cmake}"
      "${_flutter_inappwebview_windows_cmake_contents}")
  endif()
  unset(_flutter_inappwebview_windows_cmake_contents)
endif()
unset(_flutter_inappwebview_windows_cmake)

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# Third-party Windows plugin sources (and vendor headers they pull in) emit a
# lot of MSVC noise. Keep /WX for our runner; silence known plugin chatter.
if(MSVC)
  if(TARGET flutter_inappwebview_windows_plugin)
    target_compile_options(flutter_inappwebview_windows_plugin PRIVATE
      /wd4244  # int64→int narrowing in plugin sources
      /wd4458  # WebView2EnvironmentOptions.h hides class members
    )
  endif()
  if(TARGET spine_flutter)
    target_compile_definitions(spine_flutter PRIVATE
      _CRT_SECURE_NO_WARNINGS
      _CRT_NONSTDC_NO_WARNINGS
    )
    target_compile_options(spine_flutter PRIVATE /wd4244 /wd4996)
  endif()
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
# Always force install next to the exe. A stale CMake cache can otherwise
# keep the default "C:/Program Files/..." prefix and fail without admin rights.
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
