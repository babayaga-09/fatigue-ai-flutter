import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/bundle_loader.dart';
import '../data/prefs.dart';

/// Decodes the 5 MB bundle off the UI isolate (inline on the web).
Future<Bundle> decodeInBackground(List<int> bytes) => compute(decodeBundleGz, bytes);

class AppState extends ChangeNotifier {
  AppState({required this.io, required this.prefs, this.decode = decodeInBackground,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  AppState.preloaded(Bundle b, {Prefs? prefs, DateTime Function()? clock})
      : io = BundleIo(readSeed: () async => const <int>[]),
        prefs = prefs ?? MemoryPrefs(),
        decode = decodeInline,
        clock = clock ?? DateTime.now,
        bundle = b,
        origin = BundleOrigin.seed;

  final BundleIo io;
  final Prefs prefs;
  final BundleDecoder decode;
  final DateTime Function() clock;

  Bundle? bundle;
  BundleOrigin? origin;
  bool reachable = false;
  bool needsAppUpdate = false;
  bool refreshing = false;
  Object? loadError;
  String? league;
  ThemeMode themeMode = ThemeMode.system;
  final Set<int> favourites = {};

  DateTime get now => clock();

  Future<void> start() async {
    try {
      await _restorePrefs();
    } catch (_) {
      // Preferences are a nicety; the match data must load regardless.
    }
    try {
      final local = await loadLocal(io, decode: decode);
      bundle = local.bundle;
      origin = local.origin;
    } catch (e) {
      loadError = e;
    }
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final current = bundle;
    if (current == null || refreshing) return;
    refreshing = true;
    notifyListeners();
    final r = await fetchNewer(io, current, decode: decode);
    reachable = r.reachable;
    needsAppUpdate = r.needsAppUpdate;
    if (r.bundle != null) {
      bundle = r.bundle;
      origin = BundleOrigin.network;
    }
    refreshing = false;
    notifyListeners();
  }

  void setLeague(String? id) {
    if (league == id) return;
    league = id;
    notifyListeners();
  }

  bool isFavourite(int id) => favourites.contains(id);

  Future<void> toggleFavourite(int id) async {
    if (!favourites.remove(id)) favourites.add(id);
    notifyListeners();
    await prefs.write('favourites', favourites.join(','));
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await prefs.write('theme', m.name);
  }

  Future<void> _restorePrefs() async {
    final f = await prefs.read('favourites');
    if (f != null) favourites.addAll(f.split(',').map(int.tryParse).whereType<int>());
    final t = await prefs.read('theme');
    themeMode = ThemeMode.values.firstWhere((m) => m.name == t, orElse: () => ThemeMode.system);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
