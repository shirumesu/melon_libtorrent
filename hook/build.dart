import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

/// Provides the bridge library on macOS and Linux: the prebuilt binary of
/// this release when native/prebuilt.json pins one for these exact bridge
/// sources, otherwise a source build of libtorrent and OpenSSL.
/// The Windows plugin (windows/CMakeLists.txt) does the same with CMake.
///
/// The app's pubspec can force the source build:
///
/// ```yaml
/// hooks:
///   user_defines:
///     melon_libtorrent:
///       build_from_source: true
/// ```
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    if (code.targetOS != OS.macOS && code.targetOS != OS.linux) return;
    final macOS = code.targetOS == OS.macOS;

    final architecture = switch (code.targetArchitecture) {
      Architecture.arm64 => 'arm64',
      Architecture.x64 => 'x86_64',
      final value => throw UnsupportedError('Unsupported CPU: $value'),
    };
    final deployment = macOS ? code.macOS.deploymentVersion : null;

    for (final path in [...prebuiltSources, 'native/prebuilt.json']) {
      output.dependencies.add(input.packageRoot.resolve(path));
    }

    final fromSource = input.userDefines['build_from_source'];
    if (fromSource is! bool?) {
      throw const FormatException(
        'hooks.user_defines.melon_libtorrent.build_from_source must be a '
        'boolean',
      );
    }
    final releaseArch = architecture == 'x86_64' ? 'x64' : architecture;
    final library =
        (fromSource == true
            ? null
            : await _prebuilt(
                input,
                name: macOS
                    ? 'libmelon_libtorrent-macos-$releaseArch.dylib'
                    : 'libmelon_libtorrent-linux-$releaseArch.so',
                deployment: deployment,
              )) ??
        await _buildFromSource(
          input,
          output,
          macOS: macOS,
          architecture: architecture,
          deploymentTarget: deployment == null
              ? null
              : '${deployment.major}.${deployment.minor}',
        );
    output.assets.code.add(
      CodeAsset(
        package: 'melon_libtorrent',
        name: 'src/ffi_bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: library.uri,
      ),
    );
  });
}

/// The bridge sources a prebuilt binary is built from, in fingerprint
/// order. Keep in sync with windows/CMakeLists.txt and
/// .github/workflows/release.yml.
const prebuiltSources = [
  'src/torrent_bridge.h',
  'src/torrent_bridge.cpp',
  'native/native_library_path.c',
];

/// SHA-256 of [prebuiltSources] concatenated with carriage returns removed,
/// so a checkout with CRLF line endings matches the release.
Future<String> sourceFingerprint(Uri packageRoot) async {
  final bytes = <int>[];
  for (final path in prebuiltSources) {
    final content = await File.fromUri(packageRoot.resolve(path)).readAsBytes();
    bytes.addAll(content.where((byte) => byte != 0x0D));
  }
  return sha256.convert(bytes).toString();
}

/// The verified prebuilt [name], downloaded into the shared output
/// directory once, or null when native/prebuilt.json pins none for these
/// sources or it cannot be downloaded.
Future<File?> _prebuilt(
  BuildInput input, {
  required String name,
  required AppleVersion? deployment,
}) async {
  final manifest = File.fromUri(
    input.packageRoot.resolve('native/prebuilt.json'),
  );
  if (!manifest.existsSync()) return null;
  final pins =
      jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
  final files = pins['files'] as Map<String, dynamic>? ?? const {};
  final expected = files[name] as String?;
  if (expected == null) return null;
  if (pins['sources'] != await sourceFingerprint(input.packageRoot)) {
    stderr.writeln(
      'melon_libtorrent: the bridge sources differ from release '
      '${pins['version']}; building from source.',
    );
    return null;
  }
  if (deployment != null) {
    final [major, minor] = '${pins['macosDeploymentTarget'] ?? '10.15'}'
        .split('.')
        .map(int.parse)
        .toList();
    if (deployment < AppleVersion(major, minor: minor)) return null;
  }

  // Saved under the source build's file name: Flutter names the bundled
  // framework after it and merges architectures by it.
  final directory = Directory.fromUri(
    input.outputDirectoryShared.resolve(
      'prebuilt-${pins['version']}/${name.substring(0, name.lastIndexOf('.'))}/',
    ),
  );
  final file = File.fromUri(
    directory.uri.resolve(
      name.endsWith('.dylib')
          ? 'libmelon_libtorrent.dylib'
          : 'libmelon_libtorrent.so',
    ),
  );
  if (file.existsSync() && await _sha256(file) == expected) return file;

  final url = Uri.parse('${pins['release']}/$name');
  final partial = File('${file.path}.part');
  final client = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    await directory.create(recursive: true);
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    await response.pipe(partial.openWrite());
  } on Exception catch (error) {
    stderr.writeln(
      'melon_libtorrent: could not download the prebuilt library from $url '
      '($error); building from source.',
    );
    if (partial.existsSync()) await partial.delete();
    return null;
  } finally {
    client.close(force: true);
  }
  final actual = await _sha256(partial);
  if (actual != expected) {
    await partial.delete();
    throw StateError(
      'melon_libtorrent: $url has SHA-256 $actual, but native/prebuilt.json '
      'pins $expected. Refusing to use it; set the user define '
      'melon_libtorrent: build_from_source: true to build from source.',
    );
  }
  await partial.rename(file.path);
  return file;
}

Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Builds the bridge with libtorrent and OpenSSL from pinned sources.
Future<File> _buildFromSource(
  BuildInput input,
  BuildOutputBuilder output, {
  required bool macOS,
  required String architecture,
  required String? deploymentTarget,
}) async {
  final nativeDirectory = input.outputDirectoryShared.resolve(
    macOS ? 'macos-$architecture-$deploymentTarget/' : 'linux-$architecture/',
  );
  final library = nativeDirectory.resolve(
    macOS ? 'libmelon_libtorrent.dylib' : 'libmelon_libtorrent.so',
  );
  final script = macOS ? 'native/build-macos.sh' : 'native/build-linux.sh';
  final process = await Process.start('/bin/bash', [
    input.packageRoot.resolve(script).toFilePath(),
    nativeDirectory.toFilePath(),
    architecture,
    ?deploymentTarget,
  ]);
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  if (await process.exitCode != 0) {
    throw StateError('Failed to build the libtorrent library.');
  }
  for (final path in [script, 'native/CMakeLists.txt', 'native/exports.map']) {
    output.dependencies.add(input.packageRoot.resolve(path));
  }
  return File.fromUri(library);
}
