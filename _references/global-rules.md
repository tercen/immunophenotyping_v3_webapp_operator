# Global Rules — All App Types

> Shared reference for all skills. Applies to Type 1, Type 2, and Type 3 apps equally.

---

## Typography Scale

All apps use `AppTextStyles` from the skeleton. No custom font sizes.

| Token | Size | Weight | Line Height | Use |
|-------|------|--------|-------------|-----|
| h1 | 24px | 600 | 1.25 | Page titles (rare) |
| h2 | 20px | 600 | 1.25 | Content Panel headings |
| h3 | 16px | 600 | 1.25 | Results section headings, sub-headings |
| bodyLarge | 14px | 400 | 1.5 | Large body content |
| body | 13px | 400 | 1.5 | Standard body, option text, table cells |
| bodySmall | 12px | 400 | 1.5 | Helper text, hints (muted colour) |
| label | 12px | 500 | 1.5 | Control labels, chart labels, table headers |
| labelSmall | 11px | 500 | 1.5 | Compact labels |
| sectionHeader | 11px | 600 | 1.25 | UPPERCASE section titles (0.5 letter spacing) |

---

## Line Weights — `AppLineWeights`

All `strokeWidth` values must use `AppLineWeights.*` constants. No hardcoded numbers.

**UI chrome:**

| Token | Weight | Use |
|-------|--------|-----|
| lineSubtle | 1.0px | Internal cell borders in dense data tables |
| lineStandard | 1.5px | Section dividers, panel borders, card borders |
| lineEmphasis | 2.0px | Focus states, active selection borders, progress bars |

**Visualization content:**

| Token | Weight | Use |
|-------|--------|-----|
| vizGrid | 1.0px | Background grid lines, minor tick marks |
| vizAxis | 2.0px | X and Y axis lines, major tick marks |
| vizData | 2.0px | Data series lines, vectors, connectors |
| vizHighlight | 3.0px | Selected/hovered data series, emphasis lines |

---

## 11 Control Types

All apps draw from the same control vocabulary. Reference the skeleton's `controls_section.dart` for implementation patterns.

| Control Type | Key Widget | Sizing Notes |
|---|---|---|
| Text input | `TextField` with `onChanged` | Standard |
| Dropdown | `DropdownButton<String>` with `onChanged` | Standard |
| Checkbox | `Checkbox` inside `SizedBox(16x16)`, `visualDensity: compact` | Compact |
| Radio | `Radio<String>` inside `SizedBox(16x16)`, `visualDensity: compact` | Compact |
| Switch/toggle | `Switch` inside `FittedBox` inside `SizedBox(36x20)` | Compact |
| Slider | `Slider` with `onChanged` | Standard |
| Range slider | `RangeSlider` with `onChanged` | Standard |
| Number input | `TextField` with `keyboardType: number`, nullable parse | Standard |
| Searchable input | `Autocomplete<String>` | Standard |
| Segmented button | `SegmentedButton<String>` | Standard |
| Multi-select chips | `Wrap` + `FilterChip` | Variable |

---

## Control Styling Pattern

Every control follows this theme-aware pattern:

```dart
final isDark = context.watch<ThemeProvider>().isDarkMode;
final labelColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

Text('Label', style: AppTextStyles.label.copyWith(color: labelColor)),
const SizedBox(height: AppSpacing.xs),
// control widget here
const SizedBox(height: AppSpacing.controlSpacing),
```

---

## Wiring Golden Rule

Every control follows one-way data flow through the provider:

```
control.onChanged → provider.setXxx(value) → notifyListeners() → Consumer rebuilds
```

All state flows through providers. No direct widget-to-widget communication.

---

## Theme Rules

- Left panel and top bar / header panel: fully theme-aware (light + dark)
- Graph/chart containers: always force white background with light-mode colours
- Main panel chrome (background, status text, legends): theme-aware
- Scientific visualizations: maximum contrast, white background always
