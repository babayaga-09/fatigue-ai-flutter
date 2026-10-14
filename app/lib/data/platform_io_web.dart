import 'package:http/http.dart' as http;

import 'bundle_loader.dart';
import 'seed.dart';

/// The web demo is deployed with the latest bundle beside it (same origin, no CORS).
BundleIo platformBundleIo() => BundleIo(
      readSeed: readSeedAsset,
      fetchRemote: () async {
        // the browser would otherwise keep serving its cached copy after a weekly refresh
        final url = Uri.base.resolve('data/touchline-bundle.json.gz').replace(
            queryParameters: {'v': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}'});
        final r = await http.get(url).timeout(const Duration(seconds: 20));
        return r.statusCode == 200 ? r.bodyBytes : null;
      },
    );
