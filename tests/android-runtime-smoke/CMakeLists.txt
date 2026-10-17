cmake_minimum_required(VERSION 3.22)
project(MM8AndroidRuntimeSmoke LANGUAGES C CXX)

if(NOT ANDROID)
    message(FATAL_ERROR "The runtime smoke test must use the Android NDK toolchain.")
endif()
if(NOT ANDROID_ABI STREQUAL "armeabi-v7a")
    message(FATAL_ERROR "Expected ARMv7, received ${ANDROID_ABI}")
endif()
if(NOT EXISTS "${PSXRECOMP_ROOT}/runtime/runtime.cmake")
    message(FATAL_ERROR "PSXRECOMP_ROOT must point at the pinned Android-ready framework.")
endif()
if(NOT EXISTS "${SDL_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "SDL_ROOT must point at SDL3 3.4.10 source.")
endif()

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

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

set(PSX_SDL_BACKEND "SDL3" CACHE STRING "" FORCE)
set(PSX_SDL3_FETCH OFF CACHE BOOL "" FORCE)
set(PSX_RECOMP_UI OFF CACHE BOOL "" FORCE)
set(PSX_ENABLE_VULKAN OFF CACHE BOOL "" FORCE)
set(PSX_REWIND OFF CACHE BOOL "" FORCE)

add_subdirectory("${SDL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/SDL3")
include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# Compile and link the actual PSXRecomp runtime for ARMv7 without game code.
# This catches Android/NDK/runtime dependency failures in CI without shipping
# copyrighted generated game C or a disc image.
psxrecomp_add_runtime_target(psx-runtime
    WINDOW_TITLE "Mega Man 8 Android ARMv7 runtime smoke"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
)
target_compile_options(psx-runtime PRIVATE -O2)

get_target_property(_output_name psx-runtime OUTPUT_NAME)
if(NOT _output_name STREQUAL "main")
    message(FATAL_ERROR "Android runtime smoke target must output libmain.so, got '${_output_name}'")
endif()
