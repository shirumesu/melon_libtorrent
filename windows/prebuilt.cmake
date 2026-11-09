# Prebuilt bridge for the Windows plugin: native/prebuilt.json pins the
# SHA-256 of each release binary and of the bridge sources it was built
# from (see hook/build.dart, which does the same on macOS and Linux).

set(_melon_libtorrent_root "${CMAKE_CURRENT_LIST_DIR}/..")

# SHA-256 of the bridge sources concatenated with carriage returns removed,
# so a checkout with CRLF line endings matches the release. The file list
# and order match prebuiltSources in hook/build.dart.
function(melon_libtorrent_fingerprint out_var)
  set(text "")
  foreach(path src/torrent_bridge.h src/torrent_bridge.cpp native/native_library_path.c)
    file(READ "${_melon_libtorrent_root}/${path}" content)
    string(APPEND text "${content}")
  endforeach()
  string(REPLACE "\r" "" text "${text}")
  string(SHA256 fingerprint "${text}")
  set(${out_var} "${fingerprint}" PARENT_SCOPE)
endfunction()

# Sets out_var to the verified prebuilt melon_libtorrent.dll for [asset],
# downloaded into the build directory once, or to "" when the release pins
# none for these sources or it cannot be downloaded. A checksum mismatch is
# an error.
function(melon_libtorrent_prebuilt out_var asset)
  set(${out_var} "" PARENT_SCOPE)
  set(manifest "${_melon_libtorrent_root}/native/prebuilt.json")
  if(NOT EXISTS "${manifest}")
    return()
  endif()
  file(READ "${manifest}" pins)
  string(JSON expected ERROR_VARIABLE missing GET "${pins}" files "${asset}")
  if(missing OR NOT expected)
    return()
  endif()
  string(JSON version GET "${pins}" version)
  string(JSON release GET "${pins}" release)
  string(JSON sources ERROR_VARIABLE missing GET "${pins}" sources)
  melon_libtorrent_fingerprint(fingerprint)
  if(NOT sources STREQUAL fingerprint)
    message(STATUS "melon_libtorrent: the bridge sources differ from release ${version}; building from source")
    return()
  endif()

  set(dll "${CMAKE_CURRENT_BINARY_DIR}/prebuilt-${version}/melon_libtorrent.dll")
  if(EXISTS "${dll}")
    file(SHA256 "${dll}" actual)
    if(actual STREQUAL expected)
      set(${out_var} "${dll}" PARENT_SCOPE)
      return()
    endif()
  endif()
  set(url "${release}/${asset}")
  message(STATUS "melon_libtorrent: downloading ${url}")
  file(DOWNLOAD "${url}" "${dll}.part" STATUS status TLS_VERIFY ON)
  list(GET status 0 code)
  if(NOT code EQUAL 0)
    file(REMOVE "${dll}.part")
    message(WARNING "melon_libtorrent: could not download ${url} (${status}); building from source")
    return()
  endif()
  file(SHA256 "${dll}.part" actual)
  if(NOT actual STREQUAL expected)
    file(REMOVE "${dll}.part")
    message(FATAL_ERROR
      "melon_libtorrent: ${url} has SHA-256 ${actual}, but native/prebuilt.json "
      "pins ${expected}. Refusing to use it; set the environment variable "
      "MELON_LIBTORRENT_BUILD_FROM_SOURCE=1 to build from source.")
  endif()
  file(RENAME "${dll}.part" "${dll}")
  set(${out_var} "${dll}" PARENT_SCOPE)
endfunction()
