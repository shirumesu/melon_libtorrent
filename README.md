# melon_libtorrent

[libtorrent](https://libtorrent.org) 2.1 bindings for Flutter desktop
(macOS, Windows, Linux) with a built-in HTTP streaming server for playing
torrents while they download.

Add a magnet link or a .torrent file, watch its progress, and hand any
video player an `http://127.0.0.1:…` URL that serves the file with range
requests while the pieces under the player arrive first.

melon_libtorrent grew out of the [MelonBanG](https://github.com/shirumesu/MelonBanG)
anime client, where it is developed and tested in daily use. It is a fork
of [libtorrent_flutter](https://pub.dev/packages/libtorrent_flutter) 2.0.0
by ayman708-UX, whose repository is gone and which has been unmaintained
since August 2026; see [Changes from libtorrent_flutter](#changes-from-libtorrent_flutter).

## Platforms

| Platform | Architectures | Native library |
| --- | --- | --- |
| macOS 10.15+ | arm64, x86_64 | prebuilt, or built from source |
| Windows 10+ | x64 | prebuilt, or built from source with vcpkg |
| Windows | arm64 | built from source with vcpkg (untested) |
| Linux (glibc 2.35+ for the prebuilt) | x64 | prebuilt, or built from source |
| Linux | arm64 | built from source (untested) |

Android, iOS and the web are not supported. (libtorrent_flutter had
Android and iOS runners; this fork dropped them.)

Requires Flutter 3.38 or newer: macOS and Linux use Flutter's native
assets (build hooks).

## Getting started

```yaml
dependencies:
  melon_libtorrent: ^0.1.1
```

On macOS, a sandboxed app needs both network entitlements in
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`: the
client one to reach peers and trackers, the server one for incoming peers
and the streaming server.

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

```dart
import 'package:melon_libtorrent/melon_libtorrent.dart';

await MelonLibtorrent.init(
  defaultSavePath: '/path/to/downloads',
  userAgent: 'MyApp/1.0',
);
final engine = MelonLibtorrent.instance;

final id = engine.addMagnet('magnet:?xt=urn:btih:…');
engine.torrentUpdates.listen((torrents) {
  final torrent = torrents[id];
  if (torrent == null) return;
  print('${torrent.state.label} ${(torrent.progress * 100).floor()}%');
});

// Once torrents[id].hasMetadata is true:
final stream = engine.startStream(id); // the largest video or audio file
player.open(stream.url);

// Later:
engine.stopStream(stream.id);
engine.removeTorrent(id, deleteFiles: true);
await engine.dispose();
```

[`example/`](example/lib/main.dart) is a small app that adds magnets or
.torrent files, shows their progress and opens the stream URL.

## Usage

`MelonLibtorrent` holds one libtorrent session per isolate. Status is
polled (every 600 ms by default) and emitted on `torrentUpdates` on every
poll, idle seeders included; `torrents` is the latest snapshot.

- **Adding**: `addMagnet`, `addTorrentFile` and `addResume` return a
  torrent id. `startPaused` adds a torrent without connecting to peers;
  `stopWhenReady` verifies the files already on disk and then pauses;
  `streamOnly` makes an ephemeral torrent that fetches only what a stream
  reads and is deleted with its stream. Files already on disk are verified
  and reused.
- **Queueing**: torrents are not auto-managed. libtorrent does not queue
  them, so every torrent transfers until `pauseTorrent`; queue limits and
  seeding policy are the application's.
- **Files**: `getFiles` lists the files with their verified bytes;
  `setFilePriorities` picks which download.
- **Restarts**: `saveResume` writes libtorrent fast-resume data and
  `addResume` restores from it, so a restart compares file sizes instead of
  hashing every piece (libtorrent falls back to a full check when the files
  do not match). `saveMetadata` writes a magnet's metadata as a .torrent
  file so it can be restored offline with `addTorrentFile`.
- **Settings**: `configureSession(BtConfig(...))` sets rate limits, the
  listen port, per-torrent connection limit, DHT, UPnP/NAT-PMP, IPv6, TCP,
  uTP and encryption. It replaces the listen interface given to `init`.
- **Shutdown**: `dispose` destroys the session and keeps downloaded files.
  If the isolate ends without it (hot restart), a finalizer destroys the
  session.

### Streaming

`startStream` starts an HTTP server on 127.0.0.1 for one file of a torrent
that has metadata, and returns its URL. Players can open several
connections and seek freely.

Pieces ahead of the player form a sliding window that moves each time the
player enters a piece. Only the start of the window is top priority with
deadlines, because a piece is readable only once complete and the swarm
spreads its requests over every top-priority piece; the rest ranks just
below. Reads in the file's tail, where MKV cues or a late MP4 index live,
are probes and do not move the window. While a normal torrent is streamed
its other pieces keep downloading at low priority; seeking never resumes a
torrent you paused, except a `streamOnly` one.

The window is tunable through `StreamingConfig`, passed to `init` as the
session default or to `startStream` per stream:

| Field | Default | Meaning |
| --- | --- | --- |
| `windowBytes` | 24 MiB | Size of the window ahead of the reader |
| `minWindowPieces` | 2 | Fewest pieces in the window |
| `maxWindowPieces` | 48 | Most pieces in the window |
| `criticalBytes` | 8 MiB | Leading part with top priority and deadlines (at least one piece) |
| `tailProbeFraction` | 0.02 | Share of the file at the end treated as the tail |
| `tailProbeMinBytes` | 4 MiB | Smallest tail |
| `tailProbeMaxBytes` | 32 MiB | Largest tail |

With 16 MiB pieces, a top window of 8 pieces measured 96 s to the first
frame; with the default split it took 51 s.

### Client identity and trackers

| `init` parameter | Default | Meaning |
| --- | --- | --- |
| `userAgent` | libtorrent's (`libtorrent/2.1.2`) | Client name sent to HTTP trackers and web seeds |
| `peerFingerprint` | libtorrent's (`-LT2120-`) | Peer-id prefix, Azureus style `-XXvvvv-` |
| `handshakeClientVersion` | the user agent | Client name in the extension handshake |
| `fallbackTrackers` | `MelonLibtorrent.defaultFallbackTrackers` (8 public UDP trackers) | Added to magnets that name no tracker; `[]` disables |
| `fetchTrackers` | `false` | Download ngosang's trackers_best.txt from GitHub at startup and add it to every magnet |
| `streaming` | `StreamingConfig()` | Default playback window |

The session announces to one tracker in every tier concurrently
(libtorrent's `announce_to_all_tiers`), so a tier that answers with no
peers does not hide the others. Transport, piece-picking and disk settings
are libtorrent's defaults, except the mmap disk backend.

### Debug log

Set `MELON_LIBTORRENT_LOG` to a file path in the app's environment to
trace the streaming server (requests, seeks, piece waits). Without it
nothing is written.

## Native library

The bridge (`src/torrent_bridge.cpp`) links libtorrent, OpenSSL and Boost
statically into a single library: `libmelon_libtorrent.dylib` or `.so`
through the build hook on macOS and Linux, `melon_libtorrent.dll` through
the Windows plugin. Nothing needs to be installed on users' machines (the
Windows DLL uses the Visual C++ runtime that Flutter apps already need).

### Prebuilt binaries

Each release on GitHub carries the bridge built for macOS arm64 and
x86_64, Linux x64 and Windows x64. The published package pins their
SHA-256 checksums in `native/prebuilt.json`, together with a fingerprint
of the bridge sources they were built from. At build time the hook, or the
Windows plugin's CMake, downloads the matching binary once, verifies it
and uses it.

The bridge is built from source instead when the target has no prebuilt
(for example Linux arm64), when the local bridge sources differ from the
release (a git or path dependency on unreleased code), when the download
fails, or when you ask for it. A checksum mismatch stops the build.

To always build from source:

- macOS and Linux, in the app's `pubspec.yaml` (build hooks do not see
  environment variables):

  ```yaml
  hooks:
    user_defines:
      melon_libtorrent:
        build_from_source: true
  ```

- Windows: set the environment variable
  `MELON_LIBTORRENT_BUILD_FROM_SOURCE=1` before `flutter build windows`
  (run `flutter clean` after changing it, since CMake caches the
  configuration).

### Building from source

The source build downloads libtorrent 2.1.2 and OpenSSL 3.6.5 (and on
Linux Boost 1.92.0 headers) from their release pages, verifies their
SHA-256 checksums and compiles them into the hook's output directory. The
first build takes several minutes; later builds only rebuild changed
bridge sources.

- **macOS**: Xcode command line tools and `brew install cmake ninja boost`
  (Boost headers only). Everything is compiled for the app's architecture
  and deployment target.
- **Linux**: a C/C++ toolchain, CMake 3.24+, Ninja, Perl and `curl`, e.g.
  `sudo apt-get install build-essential cmake ninja-build perl curl`.
- **Windows**: the plugin links libtorrent from vcpkg, which the app's CMake
  project provides. Add vcpkg to the top of `windows/CMakeLists.txt`,
  before `project(...)`:

  ```cmake
  include(FetchContent)
  FetchContent_Declare(vcpkg
    URL https://github.com/microsoft/vcpkg/archive/9eec002df1cd109f8f104cd966a763daf9751489.tar.gz
    URL_HASH SHA256=0e41e3fc97abf18bd84f52e711eff88ba88726aa316c4f0f41d5bbd7d7b4690e
  )
  FetchContent_MakeAvailable(vcpkg)
  set(CMAKE_TOOLCHAIN_FILE "${vcpkg_SOURCE_DIR}/scripts/buildsystems/vcpkg.cmake" CACHE FILEPATH "")
  set(VCPKG_TARGET_TRIPLET "x64-windows-static-md" CACHE STRING "")
  set(VCPKG_MANIFEST_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  ```

  then, after the existing Profile settings,
  `set(CMAKE_MAP_IMPORTED_CONFIG_PROFILE Release)` (vcpkg builds only Debug
  and Release), and a `windows/vcpkg.json`:

  ```json
  {
    "name": "my-app-native",
    "version-string": "1.0.0",
    "dependencies": [
      { "name": "libtorrent", "default-features": false, "features": ["deprfun"] }
    ]
  }
  ```

  This vcpkg release (2026.10.16) has libtorrent 2.1.2 and OpenSSL 3.6.5,
  the same versions as the macOS and Linux builds; vcpkg builds them
  (about 15 minutes the first time). The prebuilt Windows DLL is built
  exactly this way (`native/windows/`).

The macOS and Linux builds include libtorrent's WebTorrent support
(libdatachannel and libjuice); the Windows build does not.

## Changes from libtorrent_flutter

Relative to libtorrent_flutter 2.0.0 (the first two commits of this
repository hold the upstream sources and MelonBanG's changes, so the full
diff is in the history):

- **Disk recovery**: upstream set `no_recheck_incomplete_resume`, so adding
  a torrent whose files were already on disk, or force-rechecking it,
  reported zero progress and downloaded everything again. Existing pieces
  are now verified and reused.
- **Fast resume**: `saveResume`/`addResume` (written atomically), and
  `saveMetadata` to restore magnets offline.
- **States**: libtorrent states are translated explicitly; upstream cast
  them, which misreads libtorrent 2's deprecated numeric slots.
- **Trackers**: one tracker per tier is announced concurrently.
- **Streaming**: a sliding deadline window with a small top-priority head
  instead of deadlines set only once the reader blocked, tail probes
  defined by size instead of the last ten pieces (most of an episode with
  16 MiB pieces), background pieces of persistent torrents kept at low
  priority while streaming, and fewer duplicate disk reads.
- **Status**: per-file verified progress, discovery statistics (known
  peers, tracker counts, DHT nodes), status emitted on every poll.
- **Lifecycle**: `dispose` no longer deletes every download; a
  `NativeFinalizer` cleans up the session on hot restart.
- **Settings**: libtorrent's defaults replace aggressive streaming timeouts
  and a spoofed qBittorrent identity; the identity is configurable;
  `configureSession` applies the listen port and protocol switches both
  ways and per-torrent connection limits to every torrent.
- **Builds**: pinned, checksum-verified libtorrent 2.1.2 / OpenSSL 3.6.5
  source builds, prebuilt binaries verified against pinned checksums, and a
  native library named `melon_libtorrent`.
- **Scope**: desktop only; Android, iOS and their CA-bundle handling are
  gone, and the debug log is opt-in.

The Dart API stays close to libtorrent_flutter's; `CHANGELOG.md` lists
every change.

## Releasing

1. Bump `version` in `pubspec.yaml` and `CHANGELOG.md`, commit, and push a
   tag `v<version>`. `.github/workflows/release.yml` builds the four
   binaries and publishes a GitHub Release with them, `SHA256SUMS` and
   `prebuilt.json`.
2. Download that `prebuilt.json` to `native/prebuilt.json`, commit it, and
   run `dart pub publish`. The published package then uses the release's
   binaries; until this step it pins none and builds from source.

## License

GPL-3.0, inherited from libtorrent_flutter; see `LICENSE`. The native
library contains libtorrent (BSD-3-Clause), OpenSSL (Apache-2.0), Boost
(BSL-1.0) and, on macOS and Linux, libdatachannel and libjuice (MPL-2.0);
their notices are in `licenses/` and Flutter's license registry.
