import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../main.dart';

class CompareScreen extends StatefulWidget {
  final PlayerSummary playerA, playerB;
  final String league;
  const CompareScreen(
      {super.key,
      required this.playerA,
      required this.playerB,
      required this.league});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _api = ApiService();
  PlayerProfile? _a, _b;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _api.compare(
          widget.playerA.id, widget.playerB.id, widget.league);
      setState(() {
        _a = result['a'];
        _b = result['b'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  bool get _isDark => FatigueApp.of(context).isDark;
  Color get _bg   => _isDark ? const Color(0xFF080C14) : const Color(0xFFF0F4FF);
  Color get _card => _isDark ? const Color(0xFF0F1623) : Colors.white;
  Color get _text => _isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get _sub  => _isDark ? Colors.white38 : Colors.black38;

  Widget _crest(String url, {double size = 32}) {
    if (url.isEmpty) {
      return Icon(Icons.sports_soccer, color: _sub, size: size);
    }
    if (url.endsWith('.svg')) {
      return SvgPicture.network(url,
          width: size,
          height: size,
          placeholderBuilder: (_) =>
              Icon(Icons.sports_soccer, color: _sub, size: size));
    }
    return Image.network(url,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.sports_soccer, color: _sub, size: size));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Compare',
            style: GoogleFonts.dmMono(fontSize: 16, color: _text)),
        actions: [
          IconButton(
            icon: Icon(
              _isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: _text,
            ),
            onPressed: () => FatigueApp.of(context).toggleTheme(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _a == null || _b == null
              ? Center(
                  child: Text('Failed to load',
                      style: TextStyle(color: _sub)))
              : _buildComparison(_a!, _b!),
    );
  }

  Widget _buildComparison(PlayerProfile a, PlayerProfile b) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeaderRow(a, b),
          const SizedBox(height: 20),
          _buildStatComparison(a, b),
          const SizedBox(height: 16),
          _buildFixtureComparison(a, b),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(PlayerProfile a, PlayerProfile b) {
    return Row(
      children: [
        Expanded(
            child: _playerHeader(a, const Color(0xFF00E5FF))),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _card,
            shape: BoxShape.circle,
            border: Border.all(
                color: _isDark ? Colors.white12 : Colors.black12),
          ),
          child: Center(
            child: Text('VS',
                style: TextStyle(
                    color: _sub,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        Expanded(
            child: _playerHeader(b, const Color(0xFF7C4DFF))),
      ],
    );
  }

  Widget _playerHeader(PlayerProfile p, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _crest(p.teamCrest, size: 36),
          const SizedBox(height: 6),
          Text(p.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.dmSans(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(height: 2),
          Text(p.team,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _sub, fontSize: 9)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(p.posGroup,
                style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatComparison(PlayerProfile a, PlayerProfile b) {
    double avg(PlayerProfile p, double Function(RecentMatch) fn) {
      if (p.recentMatches.isEmpty) return 0;
      return p.recentMatches.map(fn).reduce((x, y) => x + y) /
          p.recentMatches.length;
    }

    final stats = [
      (
        'Avg Pass Accuracy',
        avg(a, (m) => m.completionPct),
        avg(b, (m) => m.completionPct),
        100.0
      ),
      (
        'Avg Passes / Match',
        avg(a, (m) => m.passesMade.toDouble()),
        avg(b, (m) => m.passesMade.toDouble()),
        100.0
      ),
      (
        'Avg Def. Actions',
        avg(a, (m) => m.defActions.toDouble()),
        avg(b, (m) => m.defActions.toDouble()),
        20.0
      ),
      (
        'Avg Match Rating',
        avg(a, (m) => m.matchRating),
        avg(b, (m) => m.matchRating),
        10.0
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATS COMPARISON',
              style: TextStyle(
                  color: _sub, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          ...stats.map((s) => _statBar(s.$1, s.$2, s.$3, s.$4)),
        ],
      ),
    );
  }

  Widget _statBar(
      String label, double vA, double vB, double maxVal) {
    final pA = (vA / maxVal).clamp(0.0, 1.0);
    final pB = (vB / maxVal).clamp(0.0, 1.0);
    final winA = vA >= vB;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(vA.toStringAsFixed(1),
                  style: TextStyle(
                      color: winA
                          ? const Color(0xFF00E5FF)
                          : _sub,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              Text(label,
                  style: TextStyle(color: _sub, fontSize: 10)),
              Text(vB.toStringAsFixed(1),
                  style: TextStyle(
                      color: !winA
                          ? const Color(0xFF7C4DFF)
                          : _sub,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              LinearPercentIndicator(
                percent: pB,
                lineHeight: 6,
                backgroundColor:
                    _isDark ? Colors.white12 : Colors.black12,
                progressColor: const Color(0xFF7C4DFF),
                padding: EdgeInsets.zero,
                barRadius: const Radius.circular(3),
              ),
              LinearPercentIndicator(
                percent: pA,
                lineHeight: 6,
                backgroundColor: Colors.transparent,
                progressColor:
                    const Color(0xFF00E5FF).withOpacity(0.85),
                padding: EdgeInsets.zero,
                barRadius: const Radius.circular(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureComparison(PlayerProfile a, PlayerProfile b) {
    if (a.nextFixture == null && b.nextFixture == null) {
      return const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT FIXTURE DIFFICULTY',
              style: TextStyle(
                  color: _sub, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child:
                      _fixturePill(a, const Color(0xFF00E5FF))),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _fixturePill(b, const Color(0xFF7C4DFF))),
            ],
          ),
        ],
      ),
    );
  }

  Color _diffColor(String d) => switch (d) {
        'easy' => const Color(0xFF22C55E),
        'moderate' => const Color(0xFFFBBF24),
        _ => const Color(0xFFEF4444),
      };

  Widget _fixturePill(PlayerProfile p, Color accent) {
    final f = p.nextFixture;
    if (f == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('No fixture',
            style: TextStyle(color: _sub, fontSize: 11),
            textAlign: TextAlign.center),
      );
    }
    final dc = _diffColor(f.difficulty);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dc.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dc.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('vs ${f.opponent}',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Container(
                width: 12,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: i < f.difficultyScore
                      ? dc
                      : (_isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(f.date,
              style: TextStyle(color: _sub, fontSize: 9)),
        ],
      ),
    );
  }
}