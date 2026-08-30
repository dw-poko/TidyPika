import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/treemap.dart';

void main() {
  group('squarify', () {
    test('fills the area it was given', () {
      final tiles = squarify([6, 6, 4, 3, 2, 2, 1], 600, 400);

      expect(tiles, hasLength(7));
      for (final tile in tiles) {
        expect(tile.left, greaterThanOrEqualTo(-0.001));
        expect(tile.top, greaterThanOrEqualTo(-0.001));
        expect(tile.right, lessThanOrEqualTo(600.001));
        expect(tile.bottom, lessThanOrEqualTo(400.001));
      }
    });

    test('area follows weight', () {
      final tiles = squarify([50, 25, 25], 400, 200);
      final areas = {
        for (final tile in tiles) tile.index: tile.width * tile.height,
      };

      expect(areas[0]!, closeTo(80000 * 0.5, 1));
      expect(areas[1]!, closeTo(80000 * 0.25, 1));
      expect(areas[2]!, closeTo(80000 * 0.25, 1));
    });

    test('the whole area is used up', () {
      final tiles = squarify([9, 7, 5, 4, 4, 2, 1], 300, 300);
      final covered = tiles.fold<double>(
        0,
        (sum, tile) => sum + tile.width * tile.height,
      );

      expect(covered, closeTo(300 * 300, 1));
    });

    test('rectangles do not overlap', () {
      final tiles = squarify([8, 5, 5, 3, 2, 1], 500, 300);

      for (var a = 0; a < tiles.length; a++) {
        for (var b = a + 1; b < tiles.length; b++) {
          final overlaps = tiles[a].left < tiles[b].right - 0.001 &&
              tiles[b].left < tiles[a].right - 0.001 &&
              tiles[a].top < tiles[b].bottom - 0.001 &&
              tiles[b].top < tiles[a].bottom - 0.001;

          expect(overlaps, isFalse, reason: 'tile $a overlaps tile $b');
        }
      }
    });

    test('one weight takes everything', () {
      final tiles = squarify([1], 200, 100);

      expect(tiles, hasLength(1));
      expect(tiles.single.width, closeTo(200, 0.001));
      expect(tiles.single.height, closeTo(100, 0.001));
    });

    test('nothing to lay out lays out nothing', () {
      expect(squarify(const [], 100, 100), isEmpty);
      expect(squarify(const [0, 0], 100, 100), isEmpty);
      expect(squarify(const [1, 2], 0, 100), isEmpty);
      expect(squarify(const [1, 2], 100, -5), isEmpty);
    });

    test('keeps rectangles closer to square than slicing would', () {
      // Slice-and-dice on this area would make every tile 600 wide and a few
      // pixels tall; squarifying should keep the worst one far short of that.
      final tiles = squarify(List.filled(20, 5), 600, 400);
      final worst = tiles
          .map((t) => t.width > t.height ? t.width / t.height : t.height / t.width)
          .reduce((a, b) => a > b ? a : b);

      expect(worst, lessThan(4));
    });
  });
}
