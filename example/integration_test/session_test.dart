import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:melon_libtorrent/melon_libtorrent.dart';

/// Smoke test of the bundled native library: a session starts, takes a
/// torrent, reports it, and shuts down. Needs no network.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates, uses and disposes a session', (tester) async {
    final directory = await Directory.systemTemp.createTemp('melon_lt_test');
    addTearDown(() => directory.delete(recursive: true));

    await MelonLibtorrent.init(
      defaultSavePath: directory.path,
      userAgent: 'melon_libtorrent_test/0.1.0',
      peerFingerprint: '-ML0100-',
      pollInterval: const Duration(milliseconds: 100),
    );
    final engine = MelonLibtorrent.instance;
    expect(engine.libraryVersion, startsWith('2.'));

    // The info-hash of a well-known public torrent; no peers are needed.
    const hash = 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c';
    final id = engine.addMagnet(
      'magnet:?xt=urn:btih:$hash&dn=Big+Buck+Bunny',
      null,
      false,
      true,
    );
    final snapshot = await engine.torrentUpdates.firstWhere(
      (torrents) => torrents.containsKey(id),
    );
    expect(snapshot[id]!.isPaused, isTrue);
    expect(snapshot[id]!.hasMetadata, isFalse);
    expect(engine.getFiles(id), isEmpty);
    expect(
      () => engine.startStream(id),
      throwsA(isA<Exception>()),
      reason: 'streaming needs metadata',
    );

    engine.configureSession(const BtConfig(connectionsLimit: 10));
    engine.removeTorrent(id);
    await engine.dispose();
    expect(MelonLibtorrent.isInitialized, isFalse);
  });
}
