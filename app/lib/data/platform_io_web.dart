import 'package:http/http.dart' as http;

import 'bundle_loader.dart';
import 'seed.dart';

/// Team import calls the FPL API directly, which browsers block (no CORS headers).
const canImportFplTeam = false;

/// The web demo is deployed with the latest bundles beside it (same origin, no CORS).
BundleIo platformBundleIo([String name = 'touchline-bundle.json.gz']) => BundleIo(
      readSeed: () => readSeedAsset(name),
      fetchRemote: () async {
        // the browser would otherwise keep serving its cached copy after a refresh
        final url = Uri.base.resolve('data/$name').replace(
            queryParameters: {'v': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}'});
        final r = await http.get(url).timeout(const Duration(seconds: 20));
        return r.statusCode == 200 ? r.bodyBytes : null;
      },
    );
