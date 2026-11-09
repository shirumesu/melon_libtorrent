// Models for melon_libtorrent.

/// Torrent download state, translated from libtorrent's state.
enum TorrentState {
  /// The torrent has an error; see [TorrentInfo.errorMsg].
  error,

  /// A state the bridge does not map.
  unknown,

  /// Files on disk are being hashed against the torrent.
  checkingFiles,

  /// A magnet link is fetching the torrent's metadata from peers.
  downloadingMetadata,

  /// Pieces are being downloaded.
  downloading,

  /// All wanted files are complete; not every file was wanted.
  finished,

  /// The whole torrent is complete and can be seeded.
  seeding,

  /// Disk space is being allocated.
  allocating,

  /// Fast-resume data is being checked.
  checkingResume,
}

/// Playback state of an HTTP stream.
enum StreamState {
  /// No reader is active.
  idle,

  /// The reader is waiting for pieces.
  buffering,

  /// Data is being served.
  ready,

  /// The reader jumped to another position and waits for its pieces.
  seeking,

  /// The stream failed.
  error,
}

/// Converts the native stream state to [StreamState].
StreamState streamStateFromInt(int v) {
  switch (v) {
    case 0:
      return StreamState.idle;
    case 1:
      return StreamState.buffering;
    case 2:
      return StreamState.ready;
    case 3:
      return StreamState.seeking;
    case 4:
      return StreamState.error;
    default:
      return StreamState.idle;
  }
}

/// Converts the native torrent state to [TorrentState].
TorrentState stateFromInt(int v) {
  switch (v) {
    case -2:
      return TorrentState.error;
    case 0:
      return TorrentState.checkingFiles;
    case 1:
      return TorrentState.downloadingMetadata;
    case 2:
      return TorrentState.downloading;
    case 3:
      return TorrentState.finished;
    case 4:
      return TorrentState.seeding;
    case 5:
      return TorrentState.allocating;
    case 6:
      return TorrentState.checkingResume;
    default:
      return TorrentState.unknown;
  }
}

/// Labels and groupings of [TorrentState].
extension TorrentStateX on TorrentState {
  /// An English label for the state.
  String get label {
    switch (this) {
      case TorrentState.error:
        return 'Error';
      case TorrentState.unknown:
        return 'Unknown';
      case TorrentState.checkingFiles:
        return 'Checking files';
      case TorrentState.downloadingMetadata:
        return 'Getting metadata';
      case TorrentState.downloading:
        return 'Downloading';
      case TorrentState.finished:
        return 'Finished';
      case TorrentState.seeding:
        return 'Seeding';
      case TorrentState.allocating:
        return 'Allocating';
      case TorrentState.checkingResume:
        return 'Checking resume';
    }
  }

  /// Whether the torrent is still working towards completion.
  bool get isActive =>
      this == TorrentState.downloading ||
      this == TorrentState.downloadingMetadata ||
      this == TorrentState.allocating ||
      this == TorrentState.checkingFiles ||
      this == TorrentState.checkingResume;

  /// Whether every wanted file is complete.
  bool get isDone =>
      this == TorrentState.finished || this == TorrentState.seeding;
}

/// A snapshot of one torrent, emitted by
/// [MelonLibtorrent.torrentUpdates] on every poll.
class TorrentInfo {
  /// Handle returned by the add call; valid until the torrent is removed.
  final int id;

  /// Torrent name; empty or the magnet's `dn` until metadata arrives.
  final String name;

  /// Directory the torrent's files are saved under.
  final String savePath;

  /// libtorrent's error message, or empty.
  final String errorMsg;

  /// Current state.
  final TorrentState state;

  /// Progress of the wanted pieces, 0.0–1.0.
  final double progress;

  /// Payload download rate in bytes per second.
  final int downloadRate;

  /// Payload upload rate in bytes per second.
  final int uploadRate;

  /// Verified bytes of the wanted files.
  final int totalDone;

  /// Bytes of the wanted files.
  final int totalWanted;

  /// Payload bytes uploaded since the torrent was added to this session.
  final int totalUploaded;

  /// Connected peers, seeds included.
  final int numPeers;

  /// Connected seeds.
  final int numSeeds;

  /// Whether the torrent is paused.
  final bool isPaused;

  /// Whether every wanted piece is downloaded and verified.
  final bool isFinished;

  /// Whether the torrent's metadata (file list) is known.
  final bool hasMetadata;

  /// libtorrent queue position, or -1 (auto-management is off, so torrents
  /// are not queued).
  final int queuePosition;

  /// Peers known to the torrent, connected or not.
  final int knownPeers;

  /// Trackers of the torrent.
  final int trackerCount;

  /// Trackers whose last announce succeeded on some interface.
  final int workingTrackers;

  /// Trackers whose announces failed on every interface tried.
  final int failedTrackers;

  /// Largest DHT routing table across interfaces, or -1 when DHT is
  /// disabled. Sampled every five seconds.
  final int dhtNodes;

  /// Creates a snapshot; the bridge fills it from libtorrent's status.
  const TorrentInfo({
    required this.id,
    required this.name,
    required this.savePath,
    required this.errorMsg,
    required this.state,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.totalDone,
    required this.totalWanted,
    required this.totalUploaded,
    required this.numPeers,
    required this.numSeeds,
    required this.isPaused,
    required this.isFinished,
    required this.hasMetadata,
    required this.queuePosition,
    this.knownPeers = 0,
    this.trackerCount = 0,
    this.workingTrackers = 0,
    this.failedTrackers = 0,
    this.dhtNodes = 0,
  });

  /// A copy with the given fields replaced.
  TorrentInfo copyWith({
    String? name,
    String? savePath,
    String? errorMsg,
    TorrentState? state,
    double? progress,
    int? downloadRate,
    int? uploadRate,
    int? totalDone,
    int? totalWanted,
    int? totalUploaded,
    int? numPeers,
    int? numSeeds,
    bool? isPaused,
    bool? isFinished,
    bool? hasMetadata,
    int? queuePosition,
    int? knownPeers,
    int? trackerCount,
    int? workingTrackers,
    int? failedTrackers,
    int? dhtNodes,
  }) => TorrentInfo(
    id: id,
    name: name ?? this.name,
    savePath: savePath ?? this.savePath,
    errorMsg: errorMsg ?? this.errorMsg,
    state: state ?? this.state,
    progress: progress ?? this.progress,
    downloadRate: downloadRate ?? this.downloadRate,
    uploadRate: uploadRate ?? this.uploadRate,
    totalDone: totalDone ?? this.totalDone,
    totalWanted: totalWanted ?? this.totalWanted,
    totalUploaded: totalUploaded ?? this.totalUploaded,
    numPeers: numPeers ?? this.numPeers,
    numSeeds: numSeeds ?? this.numSeeds,
    isPaused: isPaused ?? this.isPaused,
    isFinished: isFinished ?? this.isFinished,
    hasMetadata: hasMetadata ?? this.hasMetadata,
    queuePosition: queuePosition ?? this.queuePosition,
    knownPeers: knownPeers ?? this.knownPeers,
    trackerCount: trackerCount ?? this.trackerCount,
    workingTrackers: workingTrackers ?? this.workingTrackers,
    failedTrackers: failedTrackers ?? this.failedTrackers,
    dhtNodes: dhtNodes ?? this.dhtNodes,
  );

  @override
  String toString() =>
      'TorrentInfo(id=$id, name=$name, state=$state, '
      'progress=${(progress * 100).toStringAsFixed(1)}%)';
}

/// A file within a torrent, from [MelonLibtorrent.getFiles].
class FileInfo {
  /// Index of the file in the torrent, as used by [MelonLibtorrent.startStream]
  /// and [MelonLibtorrent.setFilePriorities].
  final int index;

  /// File name, as renamed on disk.
  final String name;

  /// Path relative to the torrent's save path.
  final String path;

  /// Size in bytes.
  final int size;

  /// Bytes of the file in verified pieces (piece granularity).
  final int downloadedBytes;

  /// Whether the extension is a known video or audio format.
  final bool isStreamable;

  /// Creates a file entry.
  const FileInfo({
    required this.index,
    required this.name,
    required this.path,
    required this.size,
    required this.isStreamable,
    this.downloadedBytes = 0,
  });

  @override
  String toString() =>
      'FileInfo(index=$index, name=$name, '
      'size=$size, streamable=$isStreamable)';
}

/// An HTTP stream of one file, from [MelonLibtorrent.startStream] and
/// [MelonLibtorrent.streamUpdates].
class StreamInfo {
  /// Stream handle for [MelonLibtorrent.stopStream].
  final int id;

  /// The streamed torrent.
  final int torrentId;

  /// The streamed file's index.
  final int fileIndex;

  /// URL on 127.0.0.1 serving the file with range requests; pass it to a
  /// video player.
  final String url;

  /// File size in bytes.
  final int fileSize;

  /// Byte offset the player last read.
  final int readHead;

  /// Playback state.
  final StreamState streamState;

  /// Rough seconds of contiguous data ahead of [readHead], estimated from
  /// the file size (no bitrate is parsed).
  final double bufferSeconds;

  /// Contiguous complete pieces from [readHead].
  final int bufferPieces;

  /// Pieces in the nominal 16 MiB readahead, for [bufferPct].
  final int readaheadWindow;

  /// Connected peers of the torrent.
  final int activePeers;

  /// Download rate of the torrent in bytes per second.
  final int downloadRate;

  /// Creates a stream snapshot.
  const StreamInfo({
    required this.id,
    required this.torrentId,
    required this.fileIndex,
    required this.url,
    required this.fileSize,
    required this.readHead,
    required this.streamState,
    required this.bufferSeconds,
    required this.bufferPieces,
    required this.readaheadWindow,
    required this.activePeers,
    required this.downloadRate,
  });

  /// Whether data is being served.
  bool get isReady => streamState == StreamState.ready;

  /// Whether the reader waits for pieces.
  bool get isBuffering => streamState == StreamState.buffering;

  /// Whether the reader waits after a seek.
  bool get isSeeking => streamState == StreamState.seeking;

  /// Whether the stream is neither idle nor failed.
  bool get isActive =>
      streamState != StreamState.idle && streamState != StreamState.error;

  /// Buffer fill (0.0–1.0): [bufferPieces] relative to [readaheadWindow].
  double get bufferPct => readaheadWindow > 0
      ? (bufferPieces / readaheadWindow).clamp(0.0, 1.0)
      : 0.0;

  @override
  String toString() =>
      'StreamInfo(id=$id, url=$url, state=$streamState, '
      'buffer=${bufferSeconds.toStringAsFixed(1)}s, peers=$activePeers)';
}

/// How an HTTP stream prioritizes pieces around the player's position.
///
/// Pieces ahead of the reader form a sliding window that moves each time
/// the reader enters a piece. The first [criticalBytes] of it are top
/// priority with deadlines; the rest of the window ranks just below, so the
/// swarm keeps requests flowing without spreading bandwidth over pieces the
/// player does not need yet (a piece is readable only once complete).
/// Reads in the file's tail, where containers keep their index, are probes
/// and leave the window where it is.
///
/// The defaults suit video from typical swarms, including 16 MiB pieces.
class StreamingConfig {
  /// Creates a configuration; every field defaults to the tuned value.
  const StreamingConfig({
    this.windowBytes = 24 * 1024 * 1024,
    this.minWindowPieces = 2,
    this.maxWindowPieces = 48,
    this.criticalBytes = 8 * 1024 * 1024,
    this.tailProbeFraction = 0.02,
    this.tailProbeMinBytes = 4 * 1024 * 1024,
    this.tailProbeMaxBytes = 32 * 1024 * 1024,
  }) : assert(windowBytes > 0),
       assert(minWindowPieces > 0 && maxWindowPieces >= minWindowPieces),
       assert(criticalBytes > 0),
       assert(tailProbeFraction > 0 && tailProbeFraction <= 1),
       assert(tailProbeMinBytes > 0 && tailProbeMaxBytes >= tailProbeMinBytes);

  /// Size of the window ahead of the reader (default 24 MiB), converted to
  /// whole pieces and clamped to [minWindowPieces]–[maxWindowPieces].
  final int windowBytes;

  /// Fewest pieces in the window, however large pieces are (default 2).
  final int minWindowPieces;

  /// Most pieces in the window, however small pieces are (default 48).
  final int maxWindowPieces;

  /// Leading part of the window that is top priority with deadlines
  /// (default 8 MiB); always at least one piece. A new stream gives the
  /// first [criticalBytes] of the file and its last piece deadlines.
  final int criticalBytes;

  /// Share of the file at its end treated as the tail (default 0.02, i.e.
  /// 2%), clamped to [tailProbeMinBytes]–[tailProbeMaxBytes].
  final double tailProbeFraction;

  /// Smallest tail region (default 4 MiB).
  final int tailProbeMinBytes;

  /// Largest tail region (default 32 MiB).
  final int tailProbeMaxBytes;

  /// A copy with the given fields replaced.
  StreamingConfig copyWith({
    int? windowBytes,
    int? minWindowPieces,
    int? maxWindowPieces,
    int? criticalBytes,
    double? tailProbeFraction,
    int? tailProbeMinBytes,
    int? tailProbeMaxBytes,
  }) => StreamingConfig(
    windowBytes: windowBytes ?? this.windowBytes,
    minWindowPieces: minWindowPieces ?? this.minWindowPieces,
    maxWindowPieces: maxWindowPieces ?? this.maxWindowPieces,
    criticalBytes: criticalBytes ?? this.criticalBytes,
    tailProbeFraction: tailProbeFraction ?? this.tailProbeFraction,
    tailProbeMinBytes: tailProbeMinBytes ?? this.tailProbeMinBytes,
    tailProbeMaxBytes: tailProbeMaxBytes ?? this.tailProbeMaxBytes,
  );

  @override
  String toString() =>
      'StreamingConfig(window=$windowBytes B [$minWindowPieces–'
      '$maxWindowPieces pieces], critical=$criticalBytes B, '
      'tail=${tailProbeFraction * 100}% [$tailProbeMinBytes–'
      '$tailProbeMaxBytes B])';
}

// ─── Formatting Utilities ─────────────────────────────────────────────────────

/// Format [bytes] as a human-readable string (e.g. "1.5 GB").
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  double v = bytes.toDouble();
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(decimals)} ${units[i]}';
}

/// Format bytes-per-second as a speed string.
String formatSpeed(int bps) => '${formatBytes(bps)}/s';

/// Format estimated time remaining for a torrent.
String formatEta(TorrentInfo t) {
  if (t.downloadRate <= 0) return '∞';
  final remaining = t.totalWanted - t.totalDone;
  if (remaining <= 0) return 'Done';
  final secs = remaining ~/ t.downloadRate;
  if (secs < 60) return '${secs}s';
  if (secs < 3600) return '${secs ~/ 60}m ${secs % 60}s';
  return '${secs ~/ 3600}h ${(secs % 3600) ~/ 60}m';
}

// ─── Engine Configuration — port of settings/btsets.go BTSets ────────────────

/// TorrServer-equivalent engine configuration.
///
/// Port of TorrServer's `settings.BTSets` struct. Controls cache, connections,
/// encryption, protocol toggles, rate limits, etc.
class BtConfig {
  /// Cache size in bytes (default 64 MB).
  final int cacheSize;

  /// Percentage of cache used for read-ahead (5–100, default 95).
  final int readerReadAhead;

  /// Percentage of cache preloaded on stream start (0–100, default 50).
  final int preloadCache;

  /// Maximum peer connections per torrent (default 25).
  final int connectionsLimit;

  /// Seconds of inactivity before a reader-less torrent is paused (default 30).
  final int torrentDisconnectTimeout;

  /// Force encrypted connections only.
  final bool forceEncrypt;

  /// Disable TCP transport (UTP only).
  final bool disableTcp;

  /// Disable UTP transport (TCP only).
  final bool disableUtp;

  /// Disable uploading to other peers.
  final bool disableUpload;

  /// Disable DHT peer discovery.
  final bool disableDht;

  /// Disable UPnP / NAT-PMP port forwarding.
  final bool disableUpnp;

  /// Enable IPv6 listening.
  final bool enableIpv6;

  /// Download rate limit in KB/s (0 = unlimited).
  final int downloadRateLimit;

  /// Upload rate limit in KB/s (0 = unlimited).
  final int uploadRateLimit;

  /// Port for incoming peer connections (0 = automatically allocated).
  final int peersListenPort;

  /// Enable responsive mode for readers (lower latency, more aggressive).
  final bool responsiveMode;

  /// Creates a configuration; unspecified fields take the defaults.
  const BtConfig({
    this.cacheSize = 64 * 1024 * 1024,
    this.readerReadAhead = 95,
    this.preloadCache = 50,
    this.connectionsLimit = 25,
    this.torrentDisconnectTimeout = 30,
    this.forceEncrypt = false,
    this.disableTcp = false,
    this.disableUtp = false,
    this.disableUpload = false,
    this.disableDht = false,
    this.disableUpnp = false,
    this.enableIpv6 = false,
    this.downloadRateLimit = 0,
    this.uploadRateLimit = 0,
    this.peersListenPort = 0,
    this.responsiveMode = true,
  });

  /// A copy with the given fields replaced.
  BtConfig copyWith({
    int? cacheSize,
    int? readerReadAhead,
    int? preloadCache,
    int? connectionsLimit,
    int? torrentDisconnectTimeout,
    bool? forceEncrypt,
    bool? disableTcp,
    bool? disableUtp,
    bool? disableUpload,
    bool? disableDht,
    bool? disableUpnp,
    bool? enableIpv6,
    int? downloadRateLimit,
    int? uploadRateLimit,
    int? peersListenPort,
    bool? responsiveMode,
  }) => BtConfig(
    cacheSize: cacheSize ?? this.cacheSize,
    readerReadAhead: readerReadAhead ?? this.readerReadAhead,
    preloadCache: preloadCache ?? this.preloadCache,
    connectionsLimit: connectionsLimit ?? this.connectionsLimit,
    torrentDisconnectTimeout:
        torrentDisconnectTimeout ?? this.torrentDisconnectTimeout,
    forceEncrypt: forceEncrypt ?? this.forceEncrypt,
    disableTcp: disableTcp ?? this.disableTcp,
    disableUtp: disableUtp ?? this.disableUtp,
    disableUpload: disableUpload ?? this.disableUpload,
    disableDht: disableDht ?? this.disableDht,
    disableUpnp: disableUpnp ?? this.disableUpnp,
    enableIpv6: enableIpv6 ?? this.enableIpv6,
    downloadRateLimit: downloadRateLimit ?? this.downloadRateLimit,
    uploadRateLimit: uploadRateLimit ?? this.uploadRateLimit,
    peersListenPort: peersListenPort ?? this.peersListenPort,
    responsiveMode: responsiveMode ?? this.responsiveMode,
  );

  @override
  String toString() =>
      'BtConfig(cache=${cacheSize ~/ (1024 * 1024)}MB, '
      'readAhead=$readerReadAhead%, conns=$connectionsLimit, '
      'encrypt=$forceEncrypt, responsive=$responsiveMode)';
}
