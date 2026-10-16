import 'package:flutter/material.dart';

import 'app.dart';
import 'data/platform_io.dart';
import 'data/prefs.dart';
import 'fpl/fpl_state.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(io: platformBundleIo(), prefs: DevicePrefs())..start();
  final fpl = FplState(io: platformBundleIo('fpl-bundle.json.gz'), prefs: DevicePrefs(),
      canImport: canImportFplTeam)..start();
  runApp(TouchlineApp(state: state, fpl: fpl));
}
