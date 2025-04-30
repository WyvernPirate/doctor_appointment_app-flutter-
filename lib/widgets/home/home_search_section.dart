// lib/widgets/home/home_search_section.dart
import 'package:flutter/material.dart';
import '/models/doctor.dart'; // Assuming Doctor model might be needed indirectly (e.g., for specialties)

class HomeSearchSection extends StatelessWidget {
  final TextEditingController searchController;
  final bool mapFilterActive;
  final String? selectedSpecialtyFilter;
  final Set<String> uniqueSpecialties;
  final ValueChanged<String?> onSpecialtyFilterSelected;

  const HomeSearchSection({
    super.key,
    required this.searchController,
    required this.mapFilterActive,
    required this.selectedSpecialtyFilter,
    required this.uniqueSpecialties,
    required this.onSpecialtyFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inputDecorationTheme = theme.inputDecorationTheme;

    // Define colors based on theme and map state
    Color fillColor = mapFilterActive
        ? (isDark
            ? Colors.grey.shade800.withOpacity(0.5)
            : Colors.grey.shade100)
        : inputDecorationTheme.fillColor ?? colorScheme.surface;
    Color hintColor = mapFilterActive
        ? theme.disabledColor
        : inputDecorationTheme.hintStyle?.color ?? theme.hintColor;
    Color iconColor = mapFilterActive
        ? theme.disabledColor
        : inputDecorationTheme.prefixIconColor ??
            theme.iconTheme.color ??
            colorScheme.onSurfaceVariant;
    Color clearIconColor = theme.hintColor;
    Color dividerColor = theme.dividerColor;
    Color filterIconColor = mapFilterActive
        ? theme.disabledColor
        : selectedSpecialtyFilter == null
            ? (inputDecorationTheme.suffixIconColor ??
                theme.iconTheme.color ??
                colorScheme.onSurfaceVariant)
            : colorScheme.primary; // Use primary color when filter active

    return TextField(
      controller: searchController,
      enabled: !mapFilterActive,
      style: TextStyle(
        color: mapFilterActive ? theme.disabledColor : null,
      ), // Dim text if map active
      decoration: InputDecoration(
        filled: inputDecorationTheme.filled ?? true,
        fillColor: fillColor,
        contentPadding: inputDecorationTheme.contentPadding ??
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
        hintText:
            mapFilterActive ? 'Map View Active' : 'Search Doctor or Specialty...',
        hintStyle: inputDecorationTheme.hintStyle?.copyWith(color: hintColor) ??
            TextStyle(color: hintColor, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 15, right: 10),
          child: Icon(Icons.search, size: 22, color: iconColor),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clear button
            // Use ListenableBuilder to react to controller changes for the clear button
            ListenableBuilder(
              listenable: searchController,
              builder: (context, child) {
                return searchController.text.isNotEmpty && !mapFilterActive
                    ? IconButton(
                        icon: Icon(Icons.clear, color: clearIconColor, size: 20),
                        tooltip: 'Clear Search',
                        onPressed: () {
                          searchController.clear();
                        },
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                      )
                    : const SizedBox(width: 48); // Keep space consistent
              },
            ),
            // Divider
            SizedBox(
              height: 30,
              child: VerticalDivider(
                color: dividerColor,
                indent: 5,
                endIndent: 5,
                thickness: 0.7,
              ),
            ),
            // Specialty Filter Popup
            PopupMenuButton<String?>(
              icon: Icon(
                Icons.filter_list_outlined,
                size: 24,
                color: filterIconColor,
              ),
              tooltip: mapFilterActive ? null : 'Filter by Specialty',
              enabled: !mapFilterActive, // Disable popup when map active
              onSelected: mapFilterActive ? null : onSpecialtyFilterSelected,
              itemBuilder: mapFilterActive
                  ? (BuildContext context) =>
                      <PopupMenuEntry<String?>>[] // No items if map active
                  : (BuildContext context) {
                    // Use theme for text style in popup
                    final popupTextStyle = theme.textTheme.bodyLarge;
                    final boldPopupTextStyle = popupTextStyle?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    );

                    List<PopupMenuEntry<String?>> menuItems = [];
                    menuItems.add(
                      PopupMenuItem<String?>(
                        value: null, // Represents 'All Specialties'
                        child: Text(
                          'All Specialties',
                          style: selectedSpecialtyFilter == null
                              ? boldPopupTextStyle
                              : popupTextStyle,
                        ),
                      ),
                    );
                    if (uniqueSpecialties.isNotEmpty) {
                      menuItems.add(const PopupMenuDivider());
                    }
                    var sortedSpecialties = uniqueSpecialties.toList()..sort();
                    for (String specialty in sortedSpecialties) {
                      menuItems.add(
                        PopupMenuItem<String?>(
                          value: specialty,
                          child: Text(
                            specialty,
                            style: selectedSpecialtyFilter == specialty
                                ? boldPopupTextStyle
                                : popupTextStyle,
                          ),
                        ),
                      );
                    }
                    return menuItems;
                  },
            ),
            const SizedBox(width: 8),
          ],
        ),
        // Use theme borders
        border: inputDecorationTheme.border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.5),
              ),
            ),
        enabledBorder: inputDecorationTheme.enabledBorder ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.5),
              ),
            ),
        focusedBorder: inputDecorationTheme.focusedBorder ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
        disabledBorder: inputDecorationTheme.disabledBorder ??
            OutlineInputBorder(
              // Style when disabled (map active)
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
      ),
    );
  }
}
