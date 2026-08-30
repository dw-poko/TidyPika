import 'dart:math' as math;

/// One rectangle of a treemap, in the units the caller laid out in.
class Tile {
  const Tile({
    required this.index,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Position in the list of weights, so the caller can find what it stands
  /// for without this file knowing anything about folders.
  final int index;

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

/// Lays weights out as rectangles filling the given area, area proportional to
/// weight, keeping each one as close to square as it can.
///
/// The squarified arrangement rather than a plain slice-and-dice: long thin
/// slivers are hard to see, hard to compare and hard to click, and the whole
/// point of drawing this is to be looked at.
///
/// Weights are taken in the order given — sorted largest first by the caller,
/// which is what keeps the big rectangles together in one corner instead of
/// scattered.
List<Tile> squarify(List<int> weights, double width, double height) {
  if (weights.isEmpty || width <= 0 || height <= 0) return const [];

  final total = weights.fold<int>(0, (sum, weight) => sum + weight);
  if (total <= 0) return const [];

  final tiles = <Tile>[];
  final scale = width * height / total;

  var left = 0.0;
  var top = 0.0;
  var remainingWidth = width;
  var remainingHeight = height;

  var start = 0;
  while (start < weights.length) {
    if (remainingWidth <= 0 || remainingHeight <= 0) break;

    final shortSide = math.min(remainingWidth, remainingHeight);

    // Grow the row while adding the next tile makes the worst aspect ratio in
    // it better; stop the moment it makes it worse.
    var end = start;
    var rowArea = 0.0;
    var worst = double.infinity;

    while (end < weights.length) {
      final area = weights[end] * scale;
      final candidate = _worstRatio(
        weights,
        start,
        end,
        rowArea + area,
        shortSide,
        scale,
      );

      if (end > start && candidate > worst) break;

      worst = candidate;
      rowArea += area;
      end++;
    }

    // The row runs along the shorter side, which is what keeps the tiles from
    // stretching as the area gets narrower.
    final thickness = rowArea / shortSide;
    var offset = 0.0;

    for (var i = start; i < end; i++) {
      final area = weights[i] * scale;
      final length = thickness > 0 ? area / thickness : 0.0;

      tiles.add(
        remainingWidth >= remainingHeight
            ? Tile(
                index: i,
                left: left,
                top: top + offset,
                width: thickness,
                height: length,
              )
            : Tile(
                index: i,
                left: left + offset,
                top: top,
                width: length,
                height: thickness,
              ),
      );

      offset += length;
    }

    if (remainingWidth >= remainingHeight) {
      left += thickness;
      remainingWidth -= thickness;
    } else {
      top += thickness;
      remainingHeight -= thickness;
    }

    start = end;
  }

  return tiles;
}

/// The worst aspect ratio in a row that ran from [start] to [end] inclusive.
double _worstRatio(
  List<int> weights,
  int start,
  int end,
  double rowArea,
  double shortSide,
  double scale,
) {
  if (rowArea <= 0) return double.infinity;

  var smallest = double.infinity;
  var largest = 0.0;

  for (var i = start; i <= end; i++) {
    final area = weights[i] * scale;
    smallest = math.min(smallest, area);
    largest = math.max(largest, area);
  }

  final side = shortSide * shortSide;
  final square = rowArea * rowArea;

  return math.max(side * largest / square, square / (side * smallest));
}
