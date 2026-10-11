import 'package:flutter/material.dart';

import 'club_detail_screen.dart';
import 'compare_screen.dart';
import 'player_detail_screen.dart';

void openClub(BuildContext context, int id) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => ClubDetailScreen(clubId: id)));

void openPlayer(BuildContext context, int id) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => PlayerDetailScreen(playerId: id)));

void openCompare(BuildContext context, int firstId) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => CompareScreen(firstId: firstId)));
