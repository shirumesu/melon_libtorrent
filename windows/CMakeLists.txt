cmake_minimum_required(VERSION 3.19)
project(melon_libtorrent LANGUAGES CXX)

# The release's prebuilt DLL when native/prebuilt.json pins one for these
# bridge sources and the target is x64, unless MELON_LIBTORRENT_BUILD_FROM_SOURCE
# is set (as a CMake variable or an environment variable).
if(NOT MELON_LIBTORRENT_BUILD_FROM_SOURCE)
  set(MELON_LIBTORRENT_BUILD_FROM_SOURCE "$ENV{MELON_LIBTORRENT_BUILD_FROM_SOURCE}")
endif()
if(CMAKE_GENERATOR_PLATFORM)
  set(_melon_libtorrent_arch "${CMAKE_GENERATOR_PLATFORM}")
else()
  set(_melon_libtorrent_arch "${CMAKE_SYSTEM_PROCESSOR}")
endif()
string(TOLOWER "${_melon_libtorrent_arch}" _melon_libtorrent_arch)
if(NOT MELON_LIBTORRENT_BUILD_FROM_SOURCE AND _melon_libtorrent_arch MATCHES "^(x64|amd64)$")
  include("${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.cmake")
  melon_libtorrent_prebuilt(_melon_libtorrent_dll melon_libtorrent-windows-x64.dll)
  if(_melon_libtorrent_dll)
    message(STATUS "melon_libtorrent: using prebuilt ${_melon_libtorrent_dll}")
    set(melon_libtorrent_bundled_libraries "${_melon_libtorrent_dll}" PARENT_SCOPE)
    return()
  endif()
endif()

# Source build: links libtorrent statically from the application's vcpkg
# (see README). vcpkg's find_package macro keeps its own policy scope, so
# prefer configs directly.
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(LibtorrentRasterbar CONFIG QUIET)
if(NOT LibtorrentRasterbar_FOUND)
  message(FATAL_ERROR
    "melon_libtorrent: no prebuilt library is available for this build and "
    "libtorrent was not found. Building from source on Windows needs "
    "libtorrent from vcpkg in the application's CMake project; see the "
    "package README.")
endif()
add_library(melon_libtorrent SHARED ../src/torrent_bridge.cpp)
target_compile_features(melon_libtorrent PRIVATE cxx_std_17)
target_compile_definitions(melon_libtorrent PRIVATE
  TORRENT_BRIDGE_EXPORTS WIN32_LEAN_AND_MEAN NOMINMAX _WIN32_WINNT=0x0A00
)
target_compile_options(melon_libtorrent PRIVATE /W3 /utf-8 /bigobj)
target_link_libraries(melon_libtorrent PRIVATE
  LibtorrentRasterbar::torrent-rasterbar ws2_32 crypt32 iphlpapi
)
set(melon_libtorrent_bundled_libraries $<TARGET_FILE:melon_libtorrent> PARENT_SCOPE)
