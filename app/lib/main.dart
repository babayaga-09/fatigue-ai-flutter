import 'package:flutter/material.dart';

import 'app.dart';
import 'data/platform_io.dart';
import 'data/prefs.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(io: platformBundleIo(), prefs: DevicePrefs())..start();
  runApp(TouchlineApp(state: state));
}
