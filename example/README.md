# melon_libtorrent example

A minimal desktop app: paste a magnet link or a .torrent file path, watch
the download, then press **Stream** to get an HTTP URL for the largest
video or audio file and open or copy it.

```sh
flutter run -d macos   # or windows, linux
```

`integration_test/session_test.dart` is an offline smoke test of the
native library: `flutter test integration_test -d macos`.
