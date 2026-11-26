/// Responsive participant-grid sizing for compact phones, landscape phones,
/// tablets and larger call surfaces. Kept independent of Flutter widgets so the
/// layout rules can be unit tested.
class GroupCallGridSpec {
  const GroupCallGridSpec._();

  static int columnsFor({
    required int participantCount,
    required double width,
    required double height,
  }) {
    final count = participantCount.clamp(1, 4).toInt();
    if (count == 1) return 1;

    final isLandscape = width > height;
    if (count == 2) {
      return width >= 620 || (isLandscape && width >= 420) ? 2 : 1;
    }

    // In a short landscape call surface, keeping all remote feeds in one row
    // gives each person more usable height than a cramped two-row grid.
    if (isLandscape && width >= 560 && height < 500) return count;
    return 2;
  }

  static double aspectRatioFor({
    required int participantCount,
    required int columns,
    required double width,
    required double height,
  }) {
    final count = participantCount.clamp(1, 4).toInt();
    final safeColumns = columns.clamp(1, count).toInt();
    final rows = (count + safeColumns - 1) ~/ safeColumns;
    const horizontalPadding = 24.0;
    const verticalPadding = 26.0;
    const spacing = 10.0;

    final tileWidth =
        (width - horizontalPadding - spacing * (safeColumns - 1)) /
            safeColumns;
    final tileHeight =
        (height - verticalPadding - spacing * (rows - 1)) / rows;
    if (tileWidth <= 0 || tileHeight <= 0) return 1.0;
    return (tileWidth / tileHeight).clamp(.72, 1.85).toDouble();
  }
}
