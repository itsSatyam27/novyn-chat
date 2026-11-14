enum QuickToggleLayoutMode {
  empty,
  single,
  split,
  twoPlusOne,
  grid,
}

/// Maps the selected shortcut count to the Settings Quick Toggle arrangement.
QuickToggleLayoutMode quickToggleLayoutModeFor(int count) {
  if (count <= 0) return QuickToggleLayoutMode.empty;
  if (count == 1) return QuickToggleLayoutMode.single;
  if (count == 2) return QuickToggleLayoutMode.split;
  if (count == 3) return QuickToggleLayoutMode.twoPlusOne;
  return QuickToggleLayoutMode.grid;
}
