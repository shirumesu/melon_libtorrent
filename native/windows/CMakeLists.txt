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
  URL https://github.com/microsoft/vcpkg/archive/9eec002df1cd109f8f104cd966a763daf9751489.tar.gz
  URL_HASH SHA256=0e41e3fc97abf18bd84f52e711eff88ba88726aa316c4f0f41d5bbd7d7b4690e
)
FetchContent_MakeAvailable(vcpkg)
set(CMAKE_TOOLCHAIN_FILE "${vcpkg_SOURCE_DIR}/scripts/buildsystems/vcpkg.cmake" CACHE FILEPATH "Native dependencies")
set(VCPKG_TARGET_TRIPLET "x64-windows-static-md" CACHE STRING "Native architecture")
set(VCPKG_MANIFEST_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
project(melon_libtorrent_release LANGUAGES CXX)

set(MELON_LIBTORRENT_BUILD_FROM_SOURCE ON)
add_subdirectory(../../windows plugin)
