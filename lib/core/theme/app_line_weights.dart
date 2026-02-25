/// Line weight tokens for UI chrome and visualization content.
/// Source: tercen-style design-tokens.md
///
/// All strokeWidth values must use these constants — no hardcoded numbers.
class AppLineWeights {
  AppLineWeights._();

  // UI chrome
  static const double lineSubtle = 1.0; // Internal cell borders, dense tables
  static const double lineStandard = 1.5; // Section dividers, panel/card borders
  static const double lineEmphasis = 2.0; // Focus states, active selection, progress bars

  // Visualization content
  static const double vizGrid = 1.0; // Background grid lines, minor tick marks
  static const double vizAxis = 2.0; // X/Y axis lines, major tick marks
  static const double vizData = 2.0; // Data series lines, vectors, connectors
  static const double vizHighlight = 3.0; // Selected/hovered data, emphasis lines
}
