# Fatigue AI — Flutter App

Mobile dashboard for the Fatigue AI footballer performance predictor.

## Features
- League → Team → Player drill-down (Top 5 European leagues)
- AI prediction card: pass accuracy, fitness score, fatigue level
- Injury risk gauge (XGBoost) + form momentum bar (GBM)
- FPL-style fixture difficulty rating (5-block bar)
- Position heatmap drawn with CustomPainter
- Match rating timeline chart (fl_chart)
- Season stats: goals, assists, yellows, reds
- Side-by-side player comparison
- Dark / light mode toggle

## Stack
Flutter · Dart · fl_chart · flutter_svg · percent_indicator

## Setup
```bash
flutter pub get
# Set API base URL in lib/services/api_service.dart
# Android emulator: http://10.0.2.2:8000
# Physical device: http://YOUR_LAN_IP:8000
flutter run
```
