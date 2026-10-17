cmake_minimum_required(VERSION 3.22)
project(MegaMan8RecompAndroid LANGUAGES C CXX)

if(NOT ANDROID)
    message(FATAL_ERROR "This CMake project must be configured by the Android Gradle plugin.")
endif()
if(NOT ANDROID_ABI STREQUAL "armeabi-v7a")
    message(FATAL_ERROR "This port targets ARMv7 only; received ${ANDROID_ABI}")
endif()

set(MM8_UPSTREAM_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/Mega-Man-8-Recomp"
    CACHE PATH "Path to the local Mega Man 8 Recomp checkout")
option(MM8_REQUIRE_GAME_RUNTIME
    "Fail configuration unless the real PSXRecomp game runtime can be built" OFF)

set(_mm8_real_runtime FALSE)
set(_mm8_game_full "")
set(_mm8_game_dispatch "")
if(EXISTS "${MM8_UPSTREAM_ROOT}/CMakeLists.txt"
   AND EXISTS "${MM8_UPSTREAM_ROOT}/psxrecomp/runtime/runtime.cmake"
   AND EXISTS "${MM8_UPSTREAM_ROOT}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxGameActivity.java")
    file(GLOB _mm8_game_full CONFIGURE_DEPENDS
        "${MM8_UPSTREAM_ROOT}/generated/*_full.c"
        "${MM8_UPSTREAM_ROOT}/generated/*_full_*.c")
    file(GLOB _mm8_game_dispatch CONFIGURE_DEPENDS
        "${MM8_UPSTREAM_ROOT}/generated/*_dispatch.c")
    if(_mm8_game_full
       AND _mm8_game_dispatch
       AND EXISTS "${MM8_UPSTREAM_ROOT}/bios-generated/OpenBIOS_full.c"
       AND EXISTS "${MM8_UPSTREAM_ROOT}/bios-generated/OpenBIOS_dispatch.c")
        set(_mm8_real_runtime TRUE)
    endif()
endif()

if(MM8_REQUIRE_GAME_RUNTIME AND NOT _mm8_real_runtime)
    message(FATAL_ERROR
        "MM8_REQUIRE_GAME_RUNTIME=ON, but the Android-ready framework checkout or generated game/OpenBIOS inputs are missing. "
        "Run scripts/prepare-upstream.sh and scripts/generate-game.sh with your own matching legal disc before building.")
endif()

# Match the Android framework's tested packaging model: SDL is static inside
# libmain.so, so PsxGameActivity loads only 'main' and does not need libSDL3.so.
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
set(SDL_GPU OFF CACHE BOOL "" FORCE)
set(SDL_RENDER ON CACHE BOOL "" FORCE)
set(SDL_CAMERA OFF CACHE BOOL "" FORCE)
set(SDL_DIALOG OFF CACHE BOOL "" FORCE)
set(SDL_TRAY OFF CACHE BOOL "" FORCE)
set(SDL_VULKAN OFF CACHE BOOL "" FORCE)
set(SDL_OPENGLES ON CACHE BOOL "" FORCE)

set(SDL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/SDL")
if(NOT EXISTS "${SDL_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "SDL3 3.4.10 source missing at ${SDL_ROOT}; run the documented setup/build workflow.")
endif()
add_subdirectory("${SDL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/SDL3")

if(_mm8_real_runtime)
    message(STATUS "Mega Man 8: configuring the real PSXRecomp Android runtime")
    message(STATUS "Game source root: ${MM8_UPSTREAM_ROOT}")

    # Keep the Android runtime independent of desktop UI and optional GPU APIs.
    # The Java launcher and touch pad are provided by the pinned Android fork.
    set(PSX_RECOMP_UI OFF CACHE BOOL "" FORCE)
    set(PSX_ENABLE_VULKAN OFF CACHE BOOL "" FORCE)
    set(PSX_REWIND OFF CACHE BOOL "" FORCE)
    set(PSX_SDL_BACKEND "SDL3" CACHE STRING "" FORCE)
    set(PSX_SDL3_FETCH OFF CACHE BOOL "" FORCE)

    add_subdirectory("${MM8_UPSTREAM_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/mm8-upstream")

    if(NOT TARGET psx-runtime)
        message(FATAL_ERROR "Upstream CMake did not create the expected psx-runtime target")
    endif()

    # Debug APKs are otherwise built at -O0, which is too slow for a CPU-bound
    # static recompilation. Optimize the runtime and generated game C as well.
    target_compile_options(psx-runtime PRIVATE -O2)

    get_target_property(_mm8_runtime_definitions psx-runtime COMPILE_DEFINITIONS)
    if(_mm8_runtime_definitions)
        list(REMOVE_ITEM _mm8_runtime_definitions "SDL_MAIN_HANDLED")
        set_property(TARGET psx-runtime PROPERTY COMPILE_DEFINITIONS
            "${_mm8_runtime_definitions}")
    endif()
    get_target_property(_mm8_runtime_definitions_after psx-runtime COMPILE_DEFINITIONS)
    if(_mm8_runtime_definitions_after AND
       "SDL_MAIN_HANDLED" IN_LIST _mm8_runtime_definitions_after)
        message(FATAL_ERROR
            "SDL_MAIN_HANDLED remains on psx-runtime; SDLActivity's SDL_main entry point would be suppressed")
    endif()

    get_target_property(_mm8_output_name psx-runtime OUTPUT_NAME)
    if(NOT _mm8_output_name STREQUAL "main")
        message(FATAL_ERROR
            "The Android framework must output libmain.so, but OUTPUT_NAME is '${_mm8_output_name}'")
    endif()
else()
    message(WARNING
        "Building the SDL3 ARMv7 bring-up shell only, NOT the game. "
        "Use MM8_REQUIRE_GAME_RUNTIME=ON to reject this fallback.")

    add_library(main SHARED main.cpp)
    target_compile_features(main PRIVATE cxx_std_17)
    target_compile_definitions(main PRIVATE SDL_MAIN_HANDLED)
    target_link_libraries(main PRIVATE SDL3::SDL3 android log GLESv2)
endif()
