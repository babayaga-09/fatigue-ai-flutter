import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'bundle_loader.dart';
import 'seed.dart';

/// Set at build time: `--dart-define=BUNDLE_URL=https://github.com/<owner>/<repo>/releases/download/data-latest/touchline-bundle.json.gz`
const bundleUrl = String.fromEnvironment('BUNDLE_URL');

BundleIo platformBundleIo() {
  Future<File> cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/touchline-bundle.json.gz');
  return BundleIo(
    readSeed: readSeedAsset,
    readCache: () async {
      final f = await cacheFile();
      return await f.exists() ? f.readAsBytes() : null;
    },
    writeCache: (bytes) async => (await cacheFile()).writeAsBytes(bytes, flush: true),
    fetchRemote: bundleUrl.isEmpty
        ? null
        : () async {
            final r = await http.get(Uri.parse(bundleUrl)).timeout(const Duration(seconds: 20));
            return r.statusCode == 200 ? r.bodyBytes : null;
          },
  );
}
