import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../data/bundle_loader.dart';
import '../data/prefs.dart';
import 'fpl_bundle.dart';
import 'fpl_optimiser.dart';
import 'squad.dart';
import 'team_import.dart';

Future<FplBundle> _decode(List<int> bytes) => compute(decodeFplGz, bytes);

/// One week's advice for the saved squad: XI, transfers, chips. Recomputed when the squad or
/// the bundle changes.
class FplAdvice {
  FplAdvice(this.bundle, this.squad) {
    final b = bundle;
    picks = squad.picks(b);
    final gws = b.gws;
    horizon = [
      for (var k = 0; k < gws.length; k++)
        {for (final p in b.players) p.id: k < p.xpts.length ? p.xpts[k] : 0.0}
    ];
    complete = picks.length == 15;
    if (!complete) return;
    xi = bestXi(picks, horizon.first);
    final pool = [for (final p in b.players) if (p.status != 'u') Pick(p.id, p.pos, p.team, p.price)];
    plans = suggestTransfers(picks, squad.sellPrices(b), squad.bank, squad.freeTransfers, pool,
        horizon.take(5).toList());
    chips = _chips(pool);
  }

  final FplBundle bundle;
  final Squad squad;
  late final List<Pick> picks;
  late final List<Map<int, double>> horizon;
  late final bool complete;
  XiResult? xi;
  List<TransferPlan> plans = const [];
  Map<String, ChipAdvice> chips = const {};

  /// The plan to show: the best one that is worth making, else rolling the transfer.
  TransferPlan? get bestPlan {
    final worth = plans.skip(1).where((p) => p.worthIt && p.gain > 0).toList();
    if (worth.isEmpty) return plans.isEmpty ? null : plans.first;
    worth.sort((a, b) => (b.gain - b.hits).compareTo(a.gain - a.hits));
    return worth.first;
  }

  Map<String, ChipAdvice> _chips(List<Pick> pool) {
    final b = bundle, gws = b.gws, out = <String, ChipAdvice>{};
    final budget = squad.value(b) + squad.bank;
    final xis = [for (final h in horizon) bestXi(picks, h)];
    final byId = {for (final p in pool) p.id: p};
    List<Pick> picksOf(List<int> ids) => [for (final i in ids) ?byId[i]];
    if (squad.chipsAvailable.contains('wildcard') && b.wildcard.isNotEmpty) {
      final (opt, over) = pickGrid(b.wildcard, budget, (g) => g.budget);
      final h5 = horizon.take(5).toList();
      final best = plans.map((p) => p.value - p.hits).fold(double.negativeInfinity,
          (a, v) => v > a ? v : a);
      final gain = horizonValue(picksOf(opt.squad), h5) - best;
      out['wildcard'] = ChipAdvice('wildcard', gws.first, gain, gain >= 12, over: over,
          squad: opt.squad);
    }
    if (squad.chipsAvailable.contains('freehit') && b.freeHit.isNotEmpty) {
      ChipAdvice? top;
      for (var k = 0; k < gws.length; k++) {
        final grid = b.freeHit.where((f) => f.gw == gws[k]).toList();
        if (grid.isEmpty) continue;
        final (opt, over) = pickGrid(grid, budget, (g) => g.budget);
        final gain = bestXi(picksOf(opt.squad), horizon[k]).points - xis[k].points;
        if (top == null || gain > top.gain) {
          top = ChipAdvice('freehit', gws[k], gain, gain >= 15, over: over, squad: opt.squad);
        }
      }
      if (top != null) out['freehit'] = top;
    }
    if (squad.chipsAvailable.contains('3xc')) {
      var k = 0;
      for (var i = 1; i < gws.length; i++) {
        if ((horizon[i][xis[i].captain] ?? 0) > (horizon[k][xis[k].captain] ?? 0)) k = i;
      }
      out['3xc'] = ChipAdvice('3xc', gws[k], horizon[k][xis[k].captain] ?? 0, true,
          player: xis[k].captain);
    }
    if (squad.chipsAvailable.contains('bboost')) {
      var k = 0;
      for (var i = 1; i < gws.length; i++) {
        if (xis[i].benchPoints > xis[k].benchPoints) k = i;
      }
      out['bboost'] = ChipAdvice('bboost', gws[k], xis[k].benchPoints, true);
    }
    return out;
  }
}

class ChipAdvice {
  const ChipAdvice(this.chip, this.gw, this.gain, this.recommend,
      {this.over = false, this.squad, this.player});
  final String chip;
  final int gw;

  /// Expected points the chip adds (Wildcard: over five gameweeks).
  final double gain;
  final bool recommend;
  final bool over;
  final List<int>? squad;
  final int? player;
}

class FplState extends ChangeNotifier {
  FplState({required this.io, required this.prefs, this.decode = _decode,
      this.canImport = false, http.Client? client})
      : client = client ?? http.Client();

  FplState.preloaded(FplBundle b, {Prefs? prefs, Squad? squad, this.canImport = false})
      : io = BundleIo(readSeed: () async => const <int>[]),
        prefs = prefs ?? MemoryPrefs(),
        decode = _decode,
        client = http.Client(),
        bundle = b,
        // ignore: prefer_initializing_formals
        _squad = squad;

  final BundleIo io;
  final Prefs prefs;
  final Future<FplBundle> Function(List<int>) decode;
  final bool canImport;
  final http.Client client;

  FplBundle? bundle;
  bool reachable = false;
  bool loading = false;
  Object? loadError;
  Squad? _squad;
  FplAdvice? _advice;

  Squad? get squad => _squad;

  FplAdvice? get advice {
    final b = bundle, s = _squad;
    if (b == null || s == null) return null;
    if (_advice == null || _advice!.bundle != b || _advice!.squad != s) {
      _advice = FplAdvice(b, s);
    }
    return _advice;
  }

  Future<void> start() async {
    loading = true;
    notifyListeners();
    try {
      _squad = Squad.decode(await prefs.read('fpl_squad'));
    } catch (_) {
      _squad = null;
    }
    try {
      final bytes = await io.readCache?.call() ?? await io.readSeed();
      bundle = await decode(bytes);
    } catch (e) {
      try {
        bundle = await decode(await io.readSeed());
      } catch (e2) {
        loadError = e2;
      }
    }
    loading = false;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final fetch = io.fetchRemote;
    if (fetch == null) return;
    try {
      final bytes = await fetch();
      if (bytes == null) return;
      final fresh = await decode(bytes);
      reachable = true;
      if (bundle == null || fresh.generatedAt.isAfter(bundle!.generatedAt)) {
        bundle = fresh;
        try {
          await io.writeCache?.call(bytes);
        } catch (_) {}
      }
    } catch (_) {
      reachable = false;
    }
    notifyListeners();
  }

  Future<void> saveSquad(Squad s) async {
    _squad = s;
    notifyListeners();
    await prefs.write('fpl_squad', s.encode());
  }

  Future<void> importById(int id) async => saveSquad(await importTeam(id, client));
}

class FplScope extends InheritedNotifier<FplState> {
  const FplScope({super.key, required FplState state, required super.child})
      : super(notifier: state);

  static FplState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FplScope>()!.notifier!;
}
