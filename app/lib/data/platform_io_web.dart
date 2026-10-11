import 'package:http/http.dart' as http;

import 'bundle_loader.dart';
import 'seed.dart';

/// The web demo is deployed with the latest bundle beside it (same origin, no CORS).
BundleIo platformBundleIo() => BundleIo(
      readSeed: readSeedAsset,
      fetchRemote: () async {
        final r = await http
            .get(Uri.base.resolve('data/touchline-bundle.json.gz'))
            .timeout(const Duration(seconds: 20));
        return r.statusCode == 200 ? r.bodyBytes : null;
      },
    );
