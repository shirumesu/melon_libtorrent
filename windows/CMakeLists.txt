cmake_minimum_required(VERSION 3.14)
project(melon_libtorrent LANGUAGES CXX)
# vcpkg's find_package macro keeps its own policy scope, so prefer configs directly.
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
find_package(LibtorrentRasterbar CONFIG REQUIRED)
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
