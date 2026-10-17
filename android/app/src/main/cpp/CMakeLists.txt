cmake_minimum_required(VERSION 3.22)
project(MegaMan8RecompAndroid LANGUAGES C CXX)

if(NOT ANDROID)
    message(FATAL_ERROR "This CMake project is intended to be built by the Android Gradle plugin.")
endif()
if(NOT ANDROID_ABI STREQUAL "armeabi-v7a")
    message(FATAL_ERROR "This initial target is ARMv7 only; received ${ANDROID_ABI}")
endif()

# The upstream PSXRecomp runtime supports Android by creating a shared target
# whose output is libmain.so. Use it only when the legally generated game and
# OpenBIOS C files are present; never silently label the SDL test shell as a game.
set(MM8_UPSTREAM_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/Mega-Man-8-Recomp"
    CACHE PATH "Path to a local Mega Man 8 Recomp checkout")
option(MM8_REQUIRE_GAME_RUNTIME
    "Fail configuration unless the real PSXRecomp game runtime can be built" OFF)

set(_mm8_real_runtime FALSE)
set(_mm8_game_full "")
set(_mm8_game_dispatch "")

if(EXISTS "${MM8_UPSTREAM_ROOT}/CMakeLists.txt"
   AND EXISTS "${MM8_UPSTREAM_ROOT}/psxrecomp/runtime/runtime.cmake")
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
        "MM8_REQUIRE_GAME_RUNTIME=ON, but the real game inputs are missing. "
        "Expected a Mega Man 8 Recomp checkout at '${MM8_UPSTREAM_ROOT}', "
        "generated/*_full*.c, generated/*_dispatch.c, and both "
        "bios-generated/OpenBIOS_*.c files. Generate these locally from your "
        "own legally obtained game disc; do not commit or distribute them.")
endif()

if(_mm8_real_runtime)
    message(STATUS "Mega Man 8: configuring the REAL PSXRecomp Android runtime")
    message(STATUS "Mega Man 8 upstream root: ${MM8_UPSTREAM_ROOT}")

    # The upstream runtime's dependency resolver accepts an existing SDL3 target.
    # Build SDL 3.4.10 as a shared library first so SDLActivity can load libSDL3.so
    # and then libmain.so. This also keeps Java and native SDL versions aligned.
    set(SDL_SHARED ON CACHE BOOL "" FORCE)
    set(SDL_STATIC OFF CACHE BOOL "" FORCE)
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
        message(FATAL_ERROR "SDL3 3.4.10 source missing at ${SDL_ROOT}")
    endif()
    add_subdirectory("${SDL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/SDL3")

    # Tell PSXRecomp to reuse this SDL3 target instead of fetching a second copy.
    set(PSX_SDL3_FETCH OFF CACHE BOOL "" FORCE)
    set(RECOMP_UI_ROOT "${MM8_UPSTREAM_ROOT}/recomp-ui" CACHE PATH "" FORCE)
    add_subdirectory("${MM8_UPSTREAM_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/mm8-upstream")

    if(NOT TARGET psx-runtime)
        message(FATAL_ERROR "Upstream CMake did not create the expected psx-runtime target")
    endif()

    # SDL3's Android Activity calls the exported SDL_main symbol. The pinned
    # recomp-ui helper adds SDL_MAIN_HANDLED to the entire runtime target, which
    # suppresses SDL_main.h's Android main->SDL_main mapping. Remove that one
    # target definition after the helper has run, allowing SDL3 3.4.10's Android
    # header to export SDL_main. Keep all other launcher/UI definitions intact.
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
            "SDL_MAIN_HANDLED remains on psx-runtime; Android SDL_main export would be suppressed")
    endif()

    get_target_property(_mm8_output_name psx-runtime OUTPUT_NAME)
    if(NOT _mm8_output_name STREQUAL "main")
        message(FATAL_ERROR
            "Android SDLActivity requires libmain.so, but upstream OUTPUT_NAME is '${_mm8_output_name}'")
    endif()
else()
    message(WARNING
        "Building the SDL3 Android bring-up shell only. This APK is NOT the game. "
        "Place a local Mega Man 8 Recomp checkout and its generated game/OpenBIOS C "
        "files in the documented locations to activate the real runtime.")

    set(SDL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/SDL")
    if(NOT EXISTS "${SDL_ROOT}/CMakeLists.txt")
        message(FATAL_ERROR "SDL3 source not found at ${SDL_ROOT}. Fetch SDL3 before building.")
    endif()

    set(SDL_SHARED ON CACHE BOOL "" FORCE)
    set(SDL_STATIC OFF CACHE BOOL "" FORCE)
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
    add_subdirectory("${SDL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/SDL3")

    add_library(main SHARED main.cpp)
    target_compile_features(main PRIVATE cxx_std_17)
    target_compile_definitions(main PRIVATE SDL_MAIN_HANDLED)
    target_link_libraries(main PRIVATE SDL3::SDL3 android log GLESv2)
endif()
