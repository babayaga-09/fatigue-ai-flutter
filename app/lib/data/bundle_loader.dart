import 'dart:convert';

import 'package:archive/archive.dart';

import 'bundle.dart';

enum BundleOrigin { network, cache, seed }

typedef BundleDecoder = Future<Bundle> Function(List<int> bytes);

Bundle decodeBundleGz(List<int> bytes) => Bundle.fromJson(
    jsonDecode(utf8.decode(const GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>);

Future<Bundle> decodeInline(List<int> bytes) async => decodeBundleGz(bytes);

class BundleIo {
  const BundleIo({required this.readSeed, this.readCache, this.writeCache, this.fetchRemote});
  final Future<List<int>> Function() readSeed;
  final Future<List<int>?> Function()? readCache;
  final Future<void> Function(List<int> bytes)? writeCache;
  final Future<List<int>?> Function()? fetchRemote;
}

class LocalLoad {
  const LocalLoad(this.bundle, this.origin);
  final Bundle bundle;
  final BundleOrigin origin;
}

class FetchResult {
  const FetchResult({required this.reachable, this.bundle});
  final bool reachable;
  final Bundle? bundle;
}

/// Cached bundle if it is valid, otherwise the seed shipped inside the app.
Future<LocalLoad> loadLocal(BundleIo io, {BundleDecoder decode = decodeInline}) async {
  try {
    final cached = await io.readCache?.call();
    if (cached != null) return LocalLoad(await decode(cached), BundleOrigin.cache);
  } catch (_) {
    // Corrupt or unsupported cache: fall through to the seed.
  }
  return LocalLoad(await decode(await io.readSeed()), BundleOrigin.seed);
}

/// Fetch the published bundle; hand it back only when it is valid and newer.
Future<FetchResult> fetchNewer(BundleIo io, Bundle current,
    {BundleDecoder decode = decodeInline}) async {
  final fetch = io.fetchRemote;
  if (fetch == null) return const FetchResult(reachable: false);
  final List<int>? bytes;
  try {
    bytes = await fetch();
  } catch (_) {
    return const FetchResult(reachable: false);
  }
  if (bytes == null) return const FetchResult(reachable: false);
  final Bundle fresh;
  try {
    fresh = await decode(bytes);
  } catch (_) {
    return const FetchResult(reachable: true);
  }
  if (!fresh.generatedAt.isAfter(current.generatedAt)) {
    return const FetchResult(reachable: true);
  }
  try {
    await io.writeCache?.call(bytes);
  } catch (_) {
    // A failed cache write must not lose the fresh data for this session.
  }
  return FetchResult(reachable: true, bundle: fresh);
}
