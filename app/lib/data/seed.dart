import 'package:flutter/services.dart';

const seedAsset = 'assets/data/touchline-bundle.json.gz';

Future<List<int>> readSeedAsset() async =>
    (await rootBundle.load(seedAsset)).buffer.asUint8List();
