cmake_minimum_required(VERSION 3.22)
project(MegaMan8RecompAndroid LANGUAGES C CXX)

if(NOT ANDROID)
    message(FATAL_ERROR "This CMake project is intended to be built by the Android Gradle plugin.")
endif()
if(NOT ANDROID_ABI STREQUAL "armeabi-v7a")
    message(FATAL_ERROR "This initial target is ARMv7 only; received ${ANDROID_ABI}")
endif()

set(SDL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/SDL")
if(NOT EXISTS "${SDL_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "SDL3 source not found at ${SDL_ROOT}. The GitHub Actions workflow must fetch SDL3 first.")
endif()

set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
add_subdirectory("${SDL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/SDL3")

add_library(mega_man_8_recomp_android SHARED main.cpp)
target_compile_features(mega_man_8_recomp_android PRIVATE cxx_std_17)
target_compile_definitions(mega_man_8_recomp_android PRIVATE SDL_MAIN_HANDLED)
target_link_libraries(mega_man_8_recomp_android PRIVATE SDL3::SDL3-static android log)
