import 'package:flutter/material.dart';

import 'screens/clubs_screen.dart';
import 'screens/home_screen.dart';
import 'screens/players_screen.dart';
import 'screens/scout_screen.dart';
import 'state/app_state.dart';
import 'theme/theme.dart';
import 'widgets/empty_note.dart';

class TouchlineApp extends StatelessWidget {
  const TouchlineApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: Builder(
          builder: (context) => MaterialApp(
            title: 'Touchline',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: AppScope.of(context).themeMode,
            builder: (context, child) => _PageWidth(child: child!),
            home: const Shell(),
          ),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  static const _dest = [
    (Icons.stadium_outlined, Icons.stadium_rounded, 'Home'),
    (Icons.shield_outlined, Icons.shield_rounded, 'Clubs'),
    (Icons.person_search_outlined, Icons.person_search_rounded, 'Players'),
    (Icons.travel_explore_outlined, Icons.travel_explore_rounded, 'Scouting'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.bundle == null) {
      return Scaffold(
        body: Center(
          child: s.loadError == null
              ? const CircularProgressIndicator()
              : const Padding(padding: EdgeInsets.all(24),
                  child: EmptyNote('The match data could not be opened. '
                      'Reinstall the app to restore it.')),
        ),
      );
    }
    final body = IndexedStack(index: index, children: const [
      HomeScreen(), ClubsScreen(), PlayersScreen(), ScoutScreen(),
    ]);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => index = 0);
      },
      child: wide
          ? Scaffold(
              body: Row(children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (o, f, l) in _dest)
                      NavigationRailDestination(icon: Icon(o), selectedIcon: Icon(f),
                          label: Text(l)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ]),
            )
          : Scaffold(
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                destinations: [
                  for (final (o, f, l) in _dest)
                    NavigationDestination(icon: Icon(o), selectedIcon: Icon(f), label: l),
                ],
              ),
            ),
    );
  }
}

/// On wide screens the programme keeps a printed page's width, centred on the stock colour,
/// instead of stretching one column across a monitor.
class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;
  static const maxWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
