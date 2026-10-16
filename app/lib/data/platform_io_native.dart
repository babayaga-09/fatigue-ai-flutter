import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'bundle_loader.dart';
import 'seed.dart';

/// Set at build time: `--dart-define=BUNDLE_URL=https://github.com/<owner>/<repo>/releases/download/data-latest/touchline-bundle.json.gz`
const bundleUrl = String.fromEnvironment('BUNDLE_URL');

const canImportFplTeam = true;

/// [name] is a file in the same release as BUNDLE_URL (e.g. fpl-bundle.json.gz).
BundleIo platformBundleIo([String name = 'touchline-bundle.json.gz']) {
  Future<File> cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/$name');
  final url = bundleUrl.isEmpty
      ? ''
      : bundleUrl.substring(0, bundleUrl.lastIndexOf('/') + 1) + name;
  return BundleIo(
    readSeed: () => readSeedAsset(name),
    readCache: () async {
      final f = await cacheFile();
      return await f.exists() ? f.readAsBytes() : null;
    },
    writeCache: (bytes) async => (await cacheFile()).writeAsBytes(bytes, flush: true),
    fetchRemote: url.isEmpty
        ? null
        : () async {
            final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
            return r.statusCode == 200 ? r.bodyBytes : null;
          },
  );
}
