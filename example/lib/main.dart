import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melon_libtorrent/melon_libtorrent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final downloads = Directory(
    '${Directory.systemTemp.path}/melon_libtorrent_example',
  );
  await downloads.create(recursive: true);
  await LibtorrentFlutter.init(
    defaultSavePath: downloads.path,
    userAgent: 'melon_libtorrent_example/1.0',
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'melon_libtorrent',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: const TorrentsPage(),
  );
}

class TorrentsPage extends StatefulWidget {
  const TorrentsPage({super.key});

  @override
  State<TorrentsPage> createState() => _TorrentsPageState();
}

class _TorrentsPageState extends State<TorrentsPage> {
  final _engine = LibtorrentFlutter.instance;
  final _input = TextEditingController();
  late final StreamSubscription<void> _updates;

  /// Stream started for each torrent, by torrent id.
  final _streams = <int, StreamInfo>{};

  @override
  void initState() {
    super.initState();
    _updates = _engine.torrentUpdates.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _updates.cancel();
    _input.dispose();
    super.dispose();
  }

  /// Adds the magnet link or .torrent file path typed into the field.
  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    try {
      text.startsWith('magnet:')
          ? _engine.addMagnet(text)
          : _engine.addTorrentFile(text);
      _input.clear();
    } on Exception catch (error) {
      _show('$error');
    }
  }

  void _stream(TorrentInfo torrent) {
    try {
      final stream = _engine.startStream(torrent.id);
      setState(() => _streams[torrent.id] = stream);
    } on Exception catch (error) {
      _show('$error');
    }
  }

  void _remove(TorrentInfo torrent) {
    if (_streams.remove(torrent.id) case final stream?) {
      _engine.stopStream(stream.id);
    }
    _engine.removeTorrent(torrent.id, deleteFiles: true);
  }

  /// Opens [url] with the system's default handler (a browser, or a player
  /// registered for HTTP video).
  Future<void> _open(String url) async {
    final (command, arguments) = Platform.isMacOS
        ? ('open', [url])
        : Platform.isWindows
        ? ('cmd', ['/c', 'start', '', url])
        : ('xdg-open', [url]);
    await Process.run(command, arguments);
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final torrents = _engine.torrents.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return Scaffold(
      appBar: AppBar(
        title: Text('melon_libtorrent · libtorrent ${_engine.libraryVersion}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      labelText: 'Magnet link or .torrent file path',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final torrent in torrents)
                  _TorrentTile(
                    torrent: torrent,
                    stream: _streams[torrent.id],
                    onStream: () => _stream(torrent),
                    onOpen: _open,
                    onRemove: () => _remove(torrent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TorrentTile extends StatelessWidget {
  const _TorrentTile({
    required this.torrent,
    required this.stream,
    required this.onStream,
    required this.onOpen,
    required this.onRemove,
  });

  final TorrentInfo torrent;
  final StreamInfo? stream;
  final VoidCallback onStream;
  final ValueChanged<String> onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = stream?.url;
    return ListTile(
      title: Text(torrent.name.isEmpty ? 'Fetching metadata…' : torrent.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          LinearProgressIndicator(value: torrent.progress),
          const SizedBox(height: 6),
          Text(
            '${torrent.state.label} · '
            '${(torrent.progress * 100).toStringAsFixed(1)}% · '
            '↓ ${formatSpeed(torrent.downloadRate)} · '
            '${torrent.numPeers} peers · ETA ${formatEta(torrent)}',
          ),
          if (url != null)
            Row(
              children: [
                Expanded(child: SelectableText(url)),
                IconButton(
                  tooltip: 'Copy stream URL',
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                ),
                IconButton(
                  tooltip: 'Open stream URL',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => onOpen(url),
                ),
              ],
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (url == null)
            TextButton(
              onPressed: torrent.hasMetadata ? onStream : null,
              child: const Text('Stream'),
            ),
          IconButton(
            tooltip: 'Remove and delete files',
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
