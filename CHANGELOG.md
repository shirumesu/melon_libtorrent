# Changelog

## 0.1.1

- Windows: the prebuilt DLL and the documented vcpkg setup move to vcpkg
  2026.10.16, so Windows gets libtorrent 2.1.2 and OpenSSL 3.6.5 (were
  2.1.1 and 3.6.4), the same versions as macOS and Linux. libtorrent 2.1.2
  no longer loses file priority updates issued in quick succession.

## 0.1.0

First release as melon_libtorrent, forked from
[libtorrent_flutter](https://pub.dev/packages/libtorrent_flutter) 2.0.0 by
ayman708-UX (its changelog covers the history before the fork) and
developed in the [MelonBanG](https://github.com/shirumesu/MelonBanG) anime
client. Desktop only: macOS, Windows and Linux.

### Native library

- libtorrent 2.1.2 and OpenSSL 3.6.5 built from pinned, SHA-256 verified
  sources by a build hook on macOS and Linux; on Windows the bridge links
  libtorrent from vcpkg. Libraries link statically into one bridge library.
- Prebuilt bridge libraries are published with each GitHub Release and
  downloaded, verified against `native/prebuilt.json`, when the bridge
  sources match the release; otherwise the bridge builds from source.
- The native library is `melon_libtorrent`, so it does not collide with
  libtorrent_flutter. The bridge's debug trace is written only when
  `MELON_LIBTORRENT_LOG` names a file (it used to go to
  `/tmp/torrent_bridge.log` unconditionally).

### Downloads

- Existing files are verified and reused when a torrent is added without
  resume data (libtorrent's `no_recheck_incomplete_resume` is off); force
  recheck keeps valid pieces.
- `saveResume`/`addResume` write and restore libtorrent fast-resume data,
  so a restart compares file sizes instead of hashing every piece.
  `saveMetadata` exports a magnet's metadata as a .torrent file.
- Add calls take `startPaused` and `stopWhenReady` flags. Torrents are not
  auto-managed; the application owns queueing.
- libtorrent states are translated explicitly (its deprecated numeric slots
  cannot be cast).
- One tracker per tier is announced concurrently
  (`announce_to_all_tiers`), so an empty tier no longer hides the others.
- `TorrentInfo` reports known peers, tracker counts and DHT nodes;
  `FileInfo.downloadedBytes` reports verified bytes per file. Status is
  emitted on every poll, including idle seeders.
- Session transport settings are libtorrent's defaults instead of
  aggressive streaming timeouts and a qBittorrent client identity;
  per-torrent connection limits apply to all torrents and the session sets
  no total cap.
- `configureSession` honours the listen port and applies the IPv6, TCP and
  uTP switches both ways when toggled.
- Native alerts are drained without printing each one.

### Streaming

- A sliding window of pieces ahead of the reader carries deadlines (about
  24 MiB, 2–48 pieces; the first 8 MiB top priority), instead of deadlines
  only after the reader blocked. Configurable with `StreamingConfig`.
- Reads in the last 2% of the file (4–32 MiB) are container probes and do
  not move the window.
- Persistent torrents keep downloading their other pieces at low priority
  while streamed; seeking no longer resumes a torrent the application
  paused.
- Cache hits consume duplicate disk reads, and concurrent readers wake on
  cached data.

### API

- Renamed: package and library `melon_libtorrent`
  (`package:melon_libtorrent/melon_libtorrent.dart`).
- Renamed: the main class is `MelonLibtorrent` (was `LibtorrentFlutter`).
- `MelonLibtorrent.init` gains `userAgent`, `peerFingerprint` and
  `handshakeClientVersion` (libtorrent's defaults when null),
  `fallbackTrackers` (the public trackers added to magnets without any,
  formerly hard-coded) and `streaming`.
- `init(fetchTrackers:)` now defaults to false.
- `startStream` gains `streaming`; `MelonLibtorrent.streamingConfig`
  holds the session default.
- `dispose` keeps downloaded files; a `NativeFinalizer` destroys the
  session when the isolate shuts down without `dispose` (hot restart).
- Removed Android and iOS support, the bundled CA certificate asset and
  `lt_set_ssl_cert_path`.
