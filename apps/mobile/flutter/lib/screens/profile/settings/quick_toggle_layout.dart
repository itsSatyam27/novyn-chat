/// Arrange Settings quick toggles into the visual rows used by the profile screen.
///
/// One item gets a full-width row; three items use two compact tiles followed by
/// one full-width tile; two and four items use balanced two-column rows.
List<List<T>> arrangeQuickToggleRows<T>(List<T> items) {
  if (items.isEmpty) return <List<T>>[];
  if (items.length == 3) {
    return <List<T>>[
      <T>[items[0], items[1]],
      <T>[items[2]],
    ];
  }

  final rows = <List<T>>[];
  for (var index = 0; index < items.length; index += 2) {
    final end = index + 2 < items.length ? index + 2 : items.length;
    rows.add(items.sublist(index, end));
  }
  return rows;
}
