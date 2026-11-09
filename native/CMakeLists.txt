cmake_minimum_required(VERSION 3.24)
if(POLICY CMP0167)
  cmake_policy(SET CMP0167 NEW)
endif()
project(melon_libtorrent LANGUAGES C CXX)

include(FetchContent)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
# The static libraries end up inside a shared one.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(OPENSSL_USE_STATIC_LIBS TRUE)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
FetchContent_Declare(libtorrent
  URL https://github.com/arvidn/libtorrent/releases/download/v2.1.2/libtorrent-rasterbar-2.1.2.tar.gz
  URL_HASH SHA256=3362546d9cd71b9e49ee6cac7d3f1f914ce9cdb217c86b63d5b22cbed0334dbc
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(libtorrent)

add_library(melon_libtorrent SHARED
  ../src/torrent_bridge.cpp
  native_library_path.c
)
target_compile_features(melon_libtorrent PRIVATE cxx_std_17)
target_link_libraries(melon_libtorrent PRIVATE torrent-rasterbar)
# Only the C bridge is exported.
if(APPLE)
  target_link_options(melon_libtorrent PRIVATE "-Wl,-exported_symbol,_lt_*" "-Wl,-dead_strip")
  set_target_properties(melon_libtorrent PROPERTIES
    BUILD_WITH_INSTALL_NAME_DIR TRUE
    INSTALL_NAME_DIR "@rpath"
  )
else()
  target_link_options(melon_libtorrent PRIVATE
    "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/exports.map" "-Wl,--gc-sections")
endif()
