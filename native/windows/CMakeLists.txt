# Builds the Windows release DLL (.github/workflows/release.yml): the
# plugin's own source build (windows/CMakeLists.txt) against a pinned vcpkg,
# the setup an application provides when it builds the plugin from source.
#   cmake -S native/windows -B build -A x64
#   cmake --build build --config Release
cmake_minimum_required(VERSION 3.21)
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()
include(FetchContent)
FetchContent_Declare(vcpkg
  URL https://github.com/microsoft/vcpkg/archive/04a9d8e5212d01ee1dd9478eadd9caade4f8b0d4.tar.gz
  URL_HASH SHA256=6c4b4bd1e2d6b1598ff001be73cd90bd596f687d9243377061b06b5b81815a24
)
FetchContent_MakeAvailable(vcpkg)
set(CMAKE_TOOLCHAIN_FILE "${vcpkg_SOURCE_DIR}/scripts/buildsystems/vcpkg.cmake" CACHE FILEPATH "Native dependencies")
set(VCPKG_TARGET_TRIPLET "x64-windows-static-md" CACHE STRING "Native architecture")
set(VCPKG_MANIFEST_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
project(melon_libtorrent_release LANGUAGES CXX)

set(MELON_LIBTORRENT_BUILD_FROM_SOURCE ON)
add_subdirectory(../../windows plugin)
