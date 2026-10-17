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
set(MM8_EXPECTED_GAME_COMMIT "e9f808fa40c04592d1d95808c658c460c1c808d9")
set(MM8_EXPECTED_FRAMEWORK_COMMIT "58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a")
option(MM8_REQUIRE_GAME_RUNTIME
    "Fail configuration unless the real PSXRecomp game runtime can be built" OFF)

function(mm8_require_nonempty_sources label)
    foreach(_source IN LISTS ARGN)
        if(NOT EXISTS "${_source}")
            message(FATAL_ERROR "${label} is missing: ${_source}")
        endif()
        file(SIZE "${_source}" _source_size)
        if(_source_size LESS 1)
            message(FATAL_ERROR "${label} is empty: ${_source}")
        endif()
    endforeach()
endfunction()

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
        "MM8_REQUIRE_GAME_RUNTIME=ON, but the Android framework checkout or generated game/OpenBIOS inputs are missing. "
        "Run scripts/prepare-upstream.sh and scripts/generate-game.sh with your own matching legal Mega Man 8 USA disc.")
endif()

if(_mm8_real_runtime)
    execute_process(
        COMMAND git -C "${MM8_UPSTREAM_ROOT}" rev-parse HEAD
        RESULT_VARIABLE _mm8_game_git_result
        OUTPUT_VARIABLE _mm8_game_commit
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    execute_process(
        COMMAND git -C "${MM8_UPSTREAM_ROOT}/psxrecomp" rev-parse HEAD
        RESULT_VARIABLE _mm8_framework_git_result
        OUTPUT_VARIABLE _mm8_framework_commit
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    if(NOT _mm8_game_git_result EQUAL 0 OR NOT _mm8_game_commit STREQUAL MM8_EXPECTED_GAME_COMMIT)
        message(FATAL_ERROR
            "Unexpected Mega Man 8 source revision. Expected ${MM8_EXPECTED_GAME_COMMIT}, got '${_mm8_game_commit}'. Run scripts/prepare-upstream.sh.")
    endif()
    if(NOT _mm8_framework_git_result EQUAL 0 OR NOT _mm8_framework_commit STREQUAL MM8_EXPECTED_FRAMEWORK_COMMIT)
        message(FATAL_ERROR
            "Unexpected PSXRecomp framework revision. Expected ${MM8_EXPECTED_FRAMEWORK_COMMIT}, got '${_mm8_framework_commit}'. Run scripts/prepare-upstream.sh.")
    endif()
    mm8_require_nonempty_sources("generated game full C" ${_mm8_game_full})
    mm8_require_nonempty_sources("generated game dispatch C" ${_mm8_game_dispatch})
    mm8_require_nonempty_sources("generated OpenBIOS C"
        "${MM8_UPSTREAM_ROOT}/bios-generated/OpenBIOS_full.c"
        "${MM8_UPSTREAM_ROOT}/bios-generated/OpenBIOS_dispatch.c")
endif()

# SDL3 is statically linked into libmain.so, matching SDLActivity's loader.
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

get_filename_component(SDL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/SDL" ABSOLUTE)
if(NOT EXISTS "${SDL_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "SDL3 ${SDL_VERSION} source missing at ${SDL_ROOT}; run the documented setup/build workflow.")
endif()

if(_mm8_real_runtime)
    message(STATUS "Mega Man 8: configuring the real PSXRecomp Android runtime")
    message(STATUS "Game source root: ${MM8_UPSTREAM_ROOT}")
    set(PSX_RECOMP_UI OFF CACHE BOOL "" FORCE)
    set(PSX_ENABLE_VULKAN OFF CACHE BOOL "" FORCE)
    set(PSX_REWIND OFF CACHE BOOL "" FORCE)
    set(PSX_SDL_BACKEND "SDL3" CACHE STRING "" FORCE)
    set(PSX_SDL3_FETCH ON CACHE BOOL "" FORCE)
    set(FETCHCONTENT_SOURCE_DIR_SDL3 "${SDL_ROOT}" CACHE PATH "" FORCE)

    add_subdirectory("${MM8_UPSTREAM_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/mm8-upstream")
    if(NOT TARGET psx-runtime)
        message(FATAL_ERROR "Upstream CMake did not create the expected psx-runtime target")
    endif()

    target_compile_options(psx-runtime PRIVATE -O3)
    get_target_property(_mm8_runtime_definitions psx-runtime COMPILE_DEFINITIONS)
    if(_mm8_runtime_definitions)
        list(REMOVE_ITEM _mm8_runtime_definitions "SDL_MAIN_HANDLED")
        set_property(TARGET psx-runtime PROPERTY COMPILE_DEFINITIONS "${_mm8_runtime_definitions}")
    endif()
    get_target_property(_mm8_runtime_definitions_after psx-runtime COMPILE_DEFINITIONS)
    if(_mm8_runtime_definitions_after AND "SDL_MAIN_HANDLED" IN_LIST _mm8_runtime_definitions_after)
        message(FATAL_ERROR "SDL_MAIN_HANDLED remains on psx-runtime; SDLActivity's SDL_main entry point would be suppressed")
    endif()
    get_target_property(_mm8_output_name psx-runtime OUTPUT_NAME)
    if(NOT _mm8_output_name STREQUAL "main")
        message(FATAL_ERROR "The Android framework must output libmain.so, but OUTPUT_NAME is '${_mm8_output_name}'")
    endif()
else()
    message(WARNING
        "Building the SDL3 ARMv7 bring-up shell only, NOT the game. "
        "Use MM8_REQUIRE_GAME_RUNTIME=ON to reject this fallback.")
    add_subdirectory("${SDL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/SDL3")
    add_library(main SHARED main.cpp)
    target_compile_features(main PRIVATE cxx_std_17)
    target_compile_definitions(main PRIVATE SDL_MAIN_HANDLED)
    target_link_libraries(main PRIVATE SDL3::SDL3 android log GLESv2)
endif()
