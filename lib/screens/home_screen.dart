import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'player_screen.dart';
import 'compare_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  List<League> _leagues = [];
  List<TeamModel> _teams = [];
  List<PlayerSummary> _players = [];
  League? _selectedLeague;
  TeamModel? _selectedTeam;
  String _search = '';
  bool _loading = false;
  String? _errorMsg;
  final List<PlayerSummary> _compareList = [];
  bool _compareMode = false;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() => _loading = true);
    try {
      _leagues = await _api.getLeagues();
      if (_leagues.isNotEmpty) {
        _selectedLeague = _leagues.first;
        await _loadTeams();
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTeams() async {
    if (_selectedLeague == null) return;
    setState(() {
      _loading = true;
      _teams = [];
      _players = [];
      _errorMsg = null;
    });
    try {
      _teams = await _api.getTeams(_selectedLeague!.code);
      if (_teams.isNotEmpty) {
        _selectedTeam = _teams.first;
        await _loadPlayers();
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPlayers() async {
    if (_selectedTeam == null) return;
    setState(() => _loading = true);
    try {
      _players = await _api.getPlayers(_selectedTeam!.id);
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<PlayerSummary> get _filtered => _players
      .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  void _openPlayer(PlayerSummary p) {
    if (_compareMode) {
      if (_compareList.length < 2 &&
          !_compareList.any((x) => x.id == p.id)) {
        setState(() => _compareList.add(p));
        if (_compareList.length == 2) _openCompare();
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(player: p, league: _selectedLeague!.code),
      ),
    );
  }

  void _openCompare() {
    if (_compareList.length < 2) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompareScreen(
          playerA: _compareList[0],
          playerB: _compareList[1],
          league: _selectedLeague!.code,
        ),
      ),
    ).then((_) => setState(() {
          _compareList.clear();
          _compareMode = false;
        }));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FatigueApp.of(context).isDark;
    final bg   = isDark ? const Color(0xFF080C14) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF0F1623) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            _buildLeagueTeamSelectors(isDark, card),
            _buildSearchBar(isDark, card),
            if (_errorMsg != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_errorMsg!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 11)),
              ),
            if (_compareMode) _buildCompareBanner(),
            Expanded(child: _buildPlayerGrid(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FATIGUE AI',
                  style: GoogleFonts.dmMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      letterSpacing: 2)),
              Text('Top 5 Leagues · LSTM Fatigue Predictor',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10)),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(
              isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            onPressed: () => FatigueApp.of(context).toggleTheme(),
          ),
          IconButton(
            tooltip: 'Compare players',
            icon: Icon(Icons.compare_arrows,
                color: _compareMode
                    ? const Color(0xFF00E5FF)
                    : (isDark ? Colors.white38 : Colors.black38)),
            onPressed: () => setState(() {
              _compareMode = !_compareMode;
              _compareList.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueTeamSelectors(bool isDark, Color card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _dropdown<League>(
              value: _selectedLeague,
              items: _leagues,
              label: (l) => l.name,
              isDark: isDark,
              card: card,
              onChanged: (l) async {
                if (l == null) return;
                setState(() {
                  _selectedLeague = l;
                  _errorMsg = null;
                });
                await _loadTeams();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dropdown<TeamModel>(
              value: _selectedTeam,
              items: _teams,
              label: (t) => t.name,
              isDark: isDark,
              card: card,
              onChanged: (t) async {
                if (t == null) return;
                setState(() {
                  _selectedTeam = t;
                  _errorMsg = null;
                });
                await _loadPlayers();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required void Function(T?) onChanged,
    required bool isDark,
    required Color card,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: DropdownButton<T>(
        isExpanded: true,
        value: value,
        underline: const SizedBox(),
        dropdownColor: card,
        style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 12),
        items: items
            .map((i) =>
                DropdownMenuItem(value: i, child: Text(label(i))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color card) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search player...',
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38),
          prefixIcon: Icon(Icons.search,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 18),
          filled: true,
          fillColor: card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _buildCompareBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C4DFF), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFF7C4DFF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _compareList.isEmpty
                  ? 'Tap 2 players to compare'
                  : _compareList.length == 1
                      ? '${_compareList[0].name} selected — pick one more'
                      : 'Loading comparison...',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _compareMode = false;
              _compareList.clear();
            }),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF7C4DFF), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerGrid(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final players = _filtered;
    if (players.isEmpty) {
      return Center(
        child: Text('No players found',
            style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: players.length,
      itemBuilder: (_, i) => _playerCard(players[i], isDark),
    );
  }

  Widget _playerCard(PlayerSummary p, bool isDark) {
    final selected = _compareList.any((x) => x.id == p.id);
    final posColor = _posColor(p.position);
    final card = isDark ? const Color(0xFF0F1623) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white38 : Colors.black38;

    return GestureDetector(
      onTap: () => _openPlayer(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF7C4DFF)
                : (isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.black.withOpacity(0.07)),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: posColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _posShort(p.position),
                    style: TextStyle(
                        color: posColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                if (p.shirtNumber != null)
                  Text('#${p.shirtNumber}',
                      style: TextStyle(color: subColor, fontSize: 10)),
              ],
            ),
            Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            Text(p.nationality,
                style: TextStyle(color: subColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Color _posColor(String pos) {
    if (pos.toLowerCase().contains('goalkeeper')) {
      return const Color(0xFFFBBF24);
    }
    if (pos.toLowerCase().contains('back') ||
        pos.toLowerCase().contains('defender')) {
      return const Color(0xFF22C55E);
    }
    if (pos.toLowerCase().contains('forward') ||
        pos.toLowerCase().contains('winger') ||
        pos.toLowerCase().contains('striker')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF00E5FF);
  }

  String _posShort(String pos) {
    if (pos.toLowerCase().contains('goalkeeper')) return 'GK';
    if (pos.toLowerCase().contains('back') ||
        pos.toLowerCase().contains('defender')) {
      return 'DEF';
    }
    if (pos.toLowerCase().contains('forward') ||
        pos.toLowerCase().contains('winger') ||
        pos.toLowerCase().contains('striker')) {
      return 'FWD';
    }
    return 'MID';
  }
}