import 'package:flutter/services.dart';

const seedAsset = 'assets/data/touchline-bundle.json.gz';

Future<List<int>> readSeedAsset([String name = 'touchline-bundle.json.gz']) async =>
    (await rootBundle.load('assets/data/$name')).buffer.asUint8List();
