import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/widgets/halftone.dart';

Uint8List _img(int w, int h, int Function(int x, int y) grey, {int alpha = 255}) {
  final b = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4, g = grey(x, y);
      b[i] = g;
      b[i + 1] = g;
      b[i + 2] = g;
      b[i + 3] = alpha;
    }
  }
  return b;
}

void main() {
  test('dark squares print big dots, white squares print none', () {
    final dots = halftone(_img(40, 20, (x, _) => x < 20 ? 0 : 255), 40, 20, 10);
    final left = dots.where((d) => d.x < 20), right = dots.where((d) => d.x > 20);
    expect(left.length, 4);
    expect(right, isEmpty);
    expect(left.every((d) => d.r > 5), isTrue);
  });

  test('dot area follows tone', () {
    final mid = halftone(_img(10, 10, (_, _) => 128), 10, 10, 10).single;
    final dark = halftone(_img(10, 10, (_, _) => 0), 10, 10, 10).single;
    expect(mid.r, lessThan(dark.r));
    expect(mid.r * mid.r / (dark.r * dark.r), closeTo(0.5, 0.05));
  });

  test('transparent pixels print nothing', () {
    expect(halftone(_img(20, 20, (_, _) => 0, alpha: 0), 20, 20, 10), isEmpty);
  });

  test('non-integer cells cover the whole image', () {
    final dots = halftone(_img(30, 30, (_, _) => 0), 30, 30, 30 / 7);
    expect(dots.length, 49);
  });

  test('a low-contrast photo is stretched to the full dot range', () {
    // greys 100..160 only: the darkest square still prints a full dot
    final dots = halftone(_img(40, 10, (x, _) => 100 + x * 60 ~/ 39), 40, 10, 10);
    final darkest = dots.reduce((a, b) => a.r > b.r ? a : b);
    expect(darkest.r, closeTo(5.2, 0.01));
  });

  test('invert prints the light tones', () {
    final dots = halftone(_img(40, 20, (x, _) => x < 20 ? 0 : 255), 40, 20, 10, invert: true);
    expect(dots.every((d) => d.x > 20), isTrue);
    expect(dots, hasLength(4));
  });
}
