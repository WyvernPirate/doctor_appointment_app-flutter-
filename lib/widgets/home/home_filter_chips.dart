// lib/widgets/home/home_filter_chips.dart
import 'package:flutter/material.dart';

class HomeFilterChips extends StatelessWidget {
  final List<String> predefinedFilters;
  final String? selectedPredefinedFilter;
  final ValueChanged<String> onFilterSelected;

  const HomeFilterChips({
    super.key,
    required this.predefinedFilters,
    required this.selectedPredefinedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    bool mapFilterActive = selectedPredefinedFilter == 'Map';
    final theme = Theme.of(context); // Get theme data
    final chipTheme = theme.chipTheme;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: predefinedFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = predefinedFilters[index];
          final isSelected = filter == selectedPredefinedFilter;

          // Determine label color based on selection and map state
          Color labelColor;
          if (isSelected) {
            labelColor = chipTheme.secondaryLabelStyle?.color ?? Colors.white;
          } else if (mapFilterActive && filter != 'Map') {
            labelColor =
                theme.disabledColor; // Dim if map active and not map chip
          } else {
            labelColor = chipTheme.labelStyle?.color ??
                theme.textTheme.bodyLarge!.color!;
          }

          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              // Only trigger if selecting a new filter
              if (selected && filter != selectedPredefinedFilter) {
                 onFilterSelected(filter);
              }
            },
            showCheckmark:
                chipTheme.showCheckmark ?? false, // Use theme default
            selectedColor: chipTheme.selectedColor, // Use theme color
            checkmarkColor: chipTheme.checkmarkColor, // Use theme color
            labelStyle: chipTheme.labelStyle?.copyWith(
              // Base style
              color: labelColor, // Apply calculated color
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: chipTheme.backgroundColor, // Use theme color
            shape: chipTheme.shape, // Use theme shape
            side: chipTheme.side, // Use theme border side
            elevation: isSelected
                ? (chipTheme.elevation ?? 2.0)
                : (chipTheme.pressElevation ?? 0.0),
            pressElevation: chipTheme.pressElevation,
          );
        },
      ),
    );
  }
}
