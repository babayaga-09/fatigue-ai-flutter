import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../main.dart';

class PlayerScreen extends StatefulWidget {
  final PlayerSummary player;
  final String league;
  const PlayerScreen({super.key, required this.player, required this.league});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  PlayerProfile? _profile;
  PredictionResult? _prediction;
  bool _loadingProfile = true;
  bool _loadingPred    = false;

  // Tab controller for sections
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _api.getPlayer(widget.player.id, widget.league);
      setState(() { _profile = profile; _loadingProfile = false; });
      await _predict(profile);
    } catch (e) {
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _predict(PlayerProfile p) async {
    if (p.recentMatches.length < 3) return;
    setState(() => _loadingPred = true);
    try {
      final seq = p.recentMatches.take(3).map((m) => [
        m.passesMade.toDouble(),
        m.defActions.toDouble(),
        0.0, 0.0, 0.0, 0.0,
        4.0,
      ]).toList();
      final result = await _api.predict(
        sequence: seq, position: p.posGroup,
      );
      setState(() => _prediction = result);
    } catch (_) {
    } finally {
      setState(() => _loadingPred = false);
    }
  }

  // ── Theme helpers ────────────────────────────────────────────
  bool get _isDark => FatigueApp.of(context).isDark;
  Color get _bg    => _isDark ? const Color(0xFF080C14) : const Color(0xFFF0F4FF);
  Color get _card  => _isDark ? const Color(0xFF0F1623) : Colors.white;
  Color get _text  => _isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get _sub   => _isDark ? Colors.white38 : Colors.black38;
  Color get _accent=> const Color(0xFF00E5FF);

  Widget _crest(String url, {double size = 36}) {
    if (url.isEmpty) return Icon(Icons.sports_soccer, color: _sub, size: size);
    if (url.endsWith('.svg')) {
      return SvgPicture.network(url, width: size, height: size,
          placeholderBuilder: (_) =>
              Icon(Icons.sports_soccer, color: _sub, size: size));
    }
    return Image.network(url, width: size, height: size,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.sports_soccer, color: _sub, size: size));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: _buildLoadingAnimation()),
      );
    }
    final p = _profile!;
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverAppBar(p),
          SliverToBoxAdapter(child: _buildTabBar()),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(p),
            _buildStatsTab(p),
            _buildAITab(p),
          ],
        ),
      ),
    );
  }

  // ── Loading animation ────────────────────────────────────────
  Widget _buildLoadingAnimation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 1),
          builder: (_, v, __) => Opacity(
            opacity: v,
            child: const Icon(Icons.bolt,
                color: Color(0xFF00E5FF), size: 64),
          ),
        ),
        const SizedBox(height: 16),
        Text('Loading player data...',
            style: TextStyle(color: _sub, fontSize: 13)),
      ],
    );
  }

  // ── Sliver App Bar ───────────────────────────────────────────
  Widget _buildSliverAppBar(PlayerProfile p) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _bg,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: _text, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            FatigueApp.of(context).isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            color: _text,
          ),
          onPressed: () => FatigueApp.of(context).toggleTheme(),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isDark
                  ? [const Color(0xFF0F1623), const Color(0xFF080C14)]
                  : [const Color(0xFFE8F0FF), const Color(0xFFF0F4FF)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
          child: Row(
            children: [
              _crest(p.teamCrest, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name,
                        style: GoogleFonts.dmSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _text)),
                    const SizedBox(height: 4),
                    Text('${p.team}  ·  ${p.position}',
                        style: TextStyle(color: _sub, fontSize: 11)),
                    Text(p.nationality,
                        style: TextStyle(color: _sub, fontSize: 10)),
                    if (_prediction != null) ...[
                      const SizedBox(height: 8),
                      _buildFitnessBar(_prediction!.fitnessScore),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFitnessBar(double score) {
    final color = score >= 75
        ? const Color(0xFF22C55E)
        : score >= 55
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);
    return Row(
      children: [
        Text('Fitness ', style: TextStyle(color: _sub, fontSize: 10)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(score.toStringAsFixed(0),
            style: GoogleFonts.dmMono(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      ],
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _bg,
      child: TabBar(
        controller: _tabController,
        labelColor: _accent,
        unselectedLabelColor: _sub,
        indicatorColor: _accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.dmMono(
            fontSize: 11, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'STATS'),
          Tab(text: 'AI MODEL'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ════════════════════════════════════════
  Widget _buildOverviewTab(PlayerProfile p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (p.nextFixture != null) _buildFixtureCard(p.nextFixture!),
          const SizedBox(height: 16),
          if (p.seasonStats != null) _buildSeasonStatsCard(p.seasonStats!),
          const SizedBox(height: 16),
          _buildRecentMatches(p),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFixtureCard(NextFixture f) {
    final color = _diffColor(f.difficulty);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('NEXT FIXTURE',
                style: TextStyle(color: _sub, fontSize: 9, letterSpacing: 1.5)),
            const Spacer(),
            // FPL 5-block bar
            Row(
              children: List.generate(5, (i) => Container(
                width: 16, height: 10,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: i < f.difficultyScore ? color : Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(6)),
              child: Text(f.difficulty.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('vs ', style: TextStyle(color: _sub, fontSize: 18)),
            Text(f.opponent,
                style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _text)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(f.homeAway,
                  style: TextStyle(color: _sub, fontSize: 10)),
            ),
            if (f.opponentRank != null) ...[
              const SizedBox(width: 8),
              Text('#${f.opponentRank} in table',
                  style: TextStyle(color: _sub, fontSize: 10)),
            ],
          ]),
          const SizedBox(height: 4),
          Text('${f.date}  ·  ${f.competition}',
              style: TextStyle(color: _sub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSeasonStatsCard(SeasonStats s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SEASON STATS',
              style: TextStyle(color: _sub, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statBox('${s.goals}',       'Goals',    const Color(0xFF22C55E)),
              _statBox('${s.assists}',     'Assists',  const Color(0xFF00E5FF)),
              _statBox('${s.appearances}', 'Apps',     Colors.white54),
              _statBox('${s.yellowCards}', 'Yellows',  const Color(0xFFFBBF24)),
              _statBox('${s.redCards}',    'Reds',     const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('Avg Rating  ',
                style: TextStyle(color: _sub, fontSize: 11)),
            Expanded(
              child: LinearPercentIndicator(
                percent: (s.avgRating / 10).clamp(0, 1),
                lineHeight: 6,
                backgroundColor: Colors.white12,
                progressColor: _ratingColor(s.avgRating),
                padding: EdgeInsets.zero,
                barRadius: const Radius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(s.avgRating.toStringAsFixed(1),
                style: GoogleFonts.dmMono(
                    color: _ratingColor(s.avgRating),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.dmMono(
              color: color, fontWeight: FontWeight.w800, fontSize: 20)),
      Text(label,
          style: TextStyle(color: _sub, fontSize: 9)),
    ]);
  }

  Color _ratingColor(double r) =>
    r >= 7.5 ? const Color(0xFF22C55E)
    : r >= 6.5 ? const Color(0xFFFBBF24)
    : const Color(0xFFEF4444);

  Widget _buildRecentMatches(PlayerProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LAST ${p.recentMatches.length} MATCHES',
            style: TextStyle(color: _sub, fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        ...p.recentMatches.map(_matchRow),
      ],
    );
  }

  Widget _matchRow(RecentMatch m) {
    final rc = m.result == 'W'
        ? const Color(0xFF22C55E)
        : m.result == 'L'
            ? const Color(0xFFEF4444)
            : const Color(0xFFFBBF24);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: rc.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Text(m.result,
              style: TextStyle(color: rc, fontSize: 10,
                  fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.homeAway} vs ${m.opponent}',
                style: TextStyle(color: _text,
                    fontWeight: FontWeight.w600, fontSize: 12)),
            Text('${m.date}  ·  ${m.score}',
                style: TextStyle(color: _sub, fontSize: 10)),
          ],
        )),
        _miniStat('${m.passesMade}', 'pass'),
        const SizedBox(width: 10),
        _miniStat('${m.defActions}',  'def'),
        const SizedBox(width: 10),
        // Rating badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _ratingColor(m.matchRating).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(m.matchRating.toStringAsFixed(1),
              style: GoogleFonts.dmMono(
                  color: _ratingColor(m.matchRating),
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _miniStat(String v, String l) => Column(children: [
    Text(v, style: GoogleFonts.dmMono(
        color: _accent, fontWeight: FontWeight.w700, fontSize: 13)),
    Text(l, style: TextStyle(color: _sub, fontSize: 8)),
  ]);

  // ════════════════════════════════════════
  // TAB 2: STATS (Charts)
  // ════════════════════════════════════════
  Widget _buildStatsTab(PlayerProfile p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildRatingChart(p),
        const SizedBox(height: 16),
        _buildAccuracyChart(p),
        const SizedBox(height: 16),
        _buildPitchHeatmap(p),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildRatingChart(PlayerProfile p) {
    if (p.recentMatches.isEmpty) return const SizedBox();
    final spots = p.recentMatches.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.matchRating)).toList();

    return _chartCard(
      title: 'MATCH RATING TIMELINE',
      minY: 4, maxY: 10,
      spots: spots,
      color: const Color(0xFF7C4DFF),
      labels: p.recentMatches.map((m) =>
          m.opponent.length > 3 ? m.opponent.substring(0,3) : m.opponent
      ).toList(),
    );
  }

  Widget _buildAccuracyChart(PlayerProfile p) {
    final valid = p.recentMatches.where((m) => m.completionPct > 0).toList();
    if (valid.isEmpty) return const SizedBox();
    final spots = valid.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.completionPct)).toList();

    return _chartCard(
      title: 'PASS ACCURACY TREND',
      minY: 60, maxY: 100,
      spots: spots,
      color: _accent,
      labels: valid.map((m) =>
          m.opponent.length > 3 ? m.opponent.substring(0,3) : m.opponent
      ).toList(),
    );
  }

  Widget _chartCard({
    required String title,
    required double minY, required double maxY,
    required List<FlSpot> spots,
    required Color color,
    required List<String> labels,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
              color: _sub, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              minY: minY, maxY: maxY,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: _isDark ? Colors.white12 : Colors.black12,
                        strokeWidth: 1),
                getDrawingVerticalLine: (_) =>
                    const FlLine(color: Colors.transparent),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 32,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: TextStyle(color: _sub, fontSize: 8)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < labels.length) {
                      return Text(labels[i],
                        style: TextStyle(color: _sub, fontSize: 8));
                    }
                    return const SizedBox();
                  },
                )),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(
                spots: spots, isCurved: true,
                color: color, barWidth: 2.5,
                dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
                    FlDotCirclePainter(
                      radius: 4, color: color,
                      strokeWidth: 2,
                      strokeColor: _isDark
                          ? const Color(0xFF080C14)
                          : Colors.white,
                    )),
                belowBarData: BarAreaData(
                    show: true, color: color.withOpacity(0.08)),
              )],
            )),
          ),
        ],
      ),
    );
  }

  // ── Pitch Heatmap ────────────────────────────────────────────
  Widget _buildPitchHeatmap(PlayerProfile p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POSITION HEATMAP',
              style: TextStyle(
                  color: _sub, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.5,
            child: CustomPaint(
              painter: _PitchPainter(
                posGroup: p.posGroup,
                isDark: _isDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _posDescription(p.posGroup),
              style: TextStyle(color: _sub, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _posDescription(String pos) => switch (pos) {
    'GK'  => 'Goalkeeper — operates in own penalty box',
    'DEF' => 'Defender — high activity in defensive third',
    'MID' => 'Midfielder — covers entire central corridor',
    'FWD' => 'Forward — concentrated in attacking third',
    _     => pos,
  };

  // ════════════════════════════════════════
  // TAB 3: AI MODEL
  // ════════════════════════════════════════
  Widget _buildAITab(PlayerProfile p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildPredictionCard(p),
        const SizedBox(height: 16),
        if (_prediction != null) ...[
          _buildInjuryCard(_prediction!),
          const SizedBox(height: 16),
          _buildFormCard(_prediction!),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildPredictionCard(PlayerProfile p) {
    final pred = _prediction;
    final acc  = pred?.predictedAccuracy ?? 0;
    final fit  = pred?.fitnessScore ?? 0;
    final gaugeColor = acc >= 82
        ? const Color(0xFF00E5FF)
        : acc >= 76 ? const Color(0xFFFBBF24)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_card, gaugeColor.withOpacity(0.1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gaugeColor.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('AI FATIGUE PREDICTION — NEXT MATCH',
            style: TextStyle(color: _sub, fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        _loadingPred
            ? const CircularProgressIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pass accuracy gauge
                  CircularPercentIndicator(
                    radius: 60, lineWidth: 8,
                    percent: (acc / 100).clamp(0, 1),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${acc.toStringAsFixed(1)}%',
                            style: GoogleFonts.dmMono(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: gaugeColor)),
                        Text('Accuracy',
                            style: TextStyle(color: _sub, fontSize: 8)),
                      ],
                    ),
                    progressColor: gaugeColor,
                    backgroundColor: Colors.white12,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  // Fitness gauge
                  CircularPercentIndicator(
                    radius: 60, lineWidth: 8,
                    percent: (fit / 100).clamp(0, 1),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(fit.toStringAsFixed(0),
                            style: GoogleFonts.dmMono(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: _fitnessColor(fit))),
                        Text('Fitness',
                            style: TextStyle(color: _sub, fontSize: 8)),
                      ],
                    ),
                    progressColor: _fitnessColor(fit),
                    backgroundColor: Colors.white12,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                ],
              ),
        if (pred != null) ...[
          const SizedBox(height: 16),
          _infoRow('Fatigue Level',  pred.fatigueLevel,
              _fatigueColor(pred.fatigueLevel)),
          const SizedBox(height: 6),
          _infoRow('Performance Drop',
              '−${pred.performanceDrop.toStringAsFixed(1)}%',
              const Color(0xFFEF4444)),
        ],
      ]),
    );
  }

  Widget _buildInjuryCard(PredictionResult pred) {
    final color = pred.injuryRiskPct > 60
        ? const Color(0xFFEF4444)
        : pred.injuryRiskPct > 30
            ? const Color(0xFFFBBF24)
            : const Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.medical_services_outlined, color: color, size: 16),
            const SizedBox(width: 6),
            Text('INJURY RISK MODEL (XGBoost)',
                style: TextStyle(color: _sub, fontSize: 9, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: LinearPercentIndicator(
                percent: (pred.injuryRiskPct / 100).clamp(0, 1),
                lineHeight: 10,
                backgroundColor: Colors.white12,
                progressColor: color,
                padding: EdgeInsets.zero,
                barRadius: const Radius.circular(5),
              ),
            ),
            const SizedBox(width: 10),
            Text('${pred.injuryRiskPct.toStringAsFixed(0)}%',
                style: GoogleFonts.dmMono(
                    color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(pred.injuryLabel,
                style: TextStyle(color: color,
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(PredictionResult pred) {
    final color = pred.formLabel == 'In Form'
        ? const Color(0xFF22C55E)
        : pred.formLabel == 'Dipping'
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_up, color: color, size: 16),
            const SizedBox(width: 6),
            Text('FORM MOMENTUM (GBM)',
                style: TextStyle(color: _sub, fontSize: 9, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: LinearPercentIndicator(
                percent: (pred.formMomentumPct / 100).clamp(0, 1),
                lineHeight: 10,
                backgroundColor: Colors.white12,
                progressColor: color,
                padding: EdgeInsets.zero,
                barRadius: const Radius.circular(5),
              ),
            ),
            const SizedBox(width: 10),
            Text('${pred.formMomentumPct.toStringAsFixed(0)}%',
                style: GoogleFonts.dmMono(
                    color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(pred.formLabel,
                style: TextStyle(color: color,
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: _sub, fontSize: 12)),
      Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    ],
  );

  Color _diffColor(String d) => switch (d) {
    'easy'     => const Color(0xFF22C55E),
    'moderate' => const Color(0xFFFBBF24),
    _          => const Color(0xFFEF4444),
  };

  Color _fitnessColor(double f) => f >= 75
      ? const Color(0xFF22C55E)
      : f >= 55 ? const Color(0xFFFBBF24)
      : const Color(0xFFEF4444);

  Color _fatigueColor(String f) => switch (f) {
    'Low'  => const Color(0xFF22C55E),
    'Moderate' => const Color(0xFFFBBF24),
    _ => const Color(0xFFEF4444),
  };
}

// ── Pitch Heatmap Painter ────────────────────────────────────
class _PitchPainter extends CustomPainter {
  final String posGroup;
  final bool isDark;
  const _PitchPainter({required this.posGroup, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pitch background
    final pitchPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1A3A1A)
          : const Color(0xFF2D6A2D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h), const Radius.circular(8)),
      pitchPaint,
    );

    // Pitch lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Outline
    canvas.drawRect(Rect.fromLTWH(4, 4, w-8, h-8), linePaint);
    // Centre line
    canvas.drawLine(Offset(w/2, 4), Offset(w/2, h-4), linePaint);
    // Centre circle
    canvas.drawCircle(Offset(w/2, h/2), h*0.2, linePaint);
    // Left penalty box
    canvas.drawRect(Rect.fromLTWH(4, h*0.2, w*0.2, h*0.6), linePaint);
    // Right penalty box
    canvas.drawRect(
        Rect.fromLTWH(w*0.8-4, h*0.2, w*0.2, h*0.6), linePaint);

    // Heatmap zones based on position
    final zones = _getHeatZones(posGroup, w, h);
    for (final zone in zones) {
      final heatPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            zone.color.withOpacity(zone.intensity),
            zone.color.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(
            center: zone.center, radius: zone.radius));
      canvas.drawCircle(zone.center, zone.radius, heatPaint);
    }
  }

  List<_HeatZone> _getHeatZones(String pos, double w, double h) {
    switch (pos) {
      case 'GK':
        return [
          _HeatZone(Offset(w*0.08, h*0.5), h*0.35,
              const Color(0xFFEF4444), 0.8),
        ];
      case 'DEF':
        return [
          _HeatZone(Offset(w*0.22, h*0.3), h*0.28,
              const Color(0xFFEF4444), 0.7),
          _HeatZone(Offset(w*0.22, h*0.7), h*0.28,
              const Color(0xFFEF4444), 0.7),
          _HeatZone(Offset(w*0.3,  h*0.5), h*0.22,
              const Color(0xFFFBBF24), 0.4),
        ];
      case 'FWD':
        return [
          _HeatZone(Offset(w*0.78, h*0.5), h*0.32,
              const Color(0xFFEF4444), 0.8),
          _HeatZone(Offset(w*0.68, h*0.3), h*0.22,
              const Color(0xFFFBBF24), 0.5),
          _HeatZone(Offset(w*0.68, h*0.7), h*0.22,
              const Color(0xFFFBBF24), 0.5),
        ];
      default: // MID
        return [
          _HeatZone(Offset(w*0.5, h*0.5), h*0.35,
              const Color(0xFFEF4444), 0.7),
          _HeatZone(Offset(w*0.4, h*0.35), h*0.22,
              const Color(0xFFFBBF24), 0.5),
          _HeatZone(Offset(w*0.6, h*0.65), h*0.22,
              const Color(0xFFFBBF24), 0.5),
        ];
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.posGroup != posGroup || old.isDark != isDark;
}

class _HeatZone {
  final Offset center;
  final double radius, intensity;
  final Color color;
  const _HeatZone(this.center, this.radius, this.color, this.intensity);
}