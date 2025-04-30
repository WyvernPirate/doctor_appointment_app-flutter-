// lib/widgets/home/home_doctor_list_view.dart
import 'package:flutter/material.dart';
import '/models/doctor.dart';
import '/widgets/doctor_list_item.dart'; // Import the list item

// Define a type alias for the favorite toggle callback
typedef FavoriteToggleCallback = Future<void> Function(String doctorId, bool currentIsFavorite);

class HomeDoctorListView extends StatelessWidget {
  final bool isLoadingDoctors;
  final String? errorLoadingDoctors;
  final List<Doctor> filteredDoctors; // The list to display
  final List<Doctor> allDoctors;      // The master list (for empty state logic)
  final String listTitle;
  final String? selectedPredefinedFilter;
  final String? selectedSpecialtyFilter;
  final String searchText;
  final bool isGuest;
  final String? loggedInUserId;
  final Set<String> togglingFavoriteIds;
  final Set<String> userFavoriteIds; // Add this parameter
  final FavoriteToggleCallback? onFavoriteToggle; // Use the type alias
  final RefreshCallback onRefresh; // For RefreshIndicator

  const HomeDoctorListView({
    super.key,
    required this.isLoadingDoctors,
    required this.errorLoadingDoctors,
    required this.filteredDoctors,
    required this.allDoctors,
    required this.listTitle,
    required this.selectedPredefinedFilter,
    required this.selectedSpecialtyFilter,
    required this.searchText,
    required this.isGuest,
    required this.loggedInUserId,
    required this.togglingFavoriteIds,
    required this.userFavoriteIds, // Make it required
    required this.onFavoriteToggle, 
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.primaryColor, // Use theme color for indicator
      child: CustomScrollView(
        slivers: <Widget>[
          // Header for Main List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 15,
                left: 16,
                right: 16,
                bottom: 10,
              ),
              child: Text(
                listTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Conditional Content: Loading, Error, Empty, or List
          _buildListContent(context),

          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // Helper to determine what content to show in the sliver area
  Widget _buildListContent(BuildContext context) {
     final theme = Theme.of(context);

    if (isLoadingDoctors && allDoctors.isEmpty) {
      // Show loading indicator only if there's no previous data
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }
    if (errorLoadingDoctors != null && allDoctors.isEmpty) {
      // Show error only if there's no previous data
      return SliverFillRemaining(child: _buildErrorWidget(context));
    }
    // Check filteredDoctors for emptiness AFTER handling loading/error for initial state
    if (!isLoadingDoctors && filteredDoctors.isEmpty) {
      if (selectedPredefinedFilter == 'Favorites' && !isGuest) {
        return SliverToBoxAdapter(child: _buildEmptyFavoritesMessage(context));
      }
      // Show general empty message if filters active or no doctors exist at all
      bool filtersActive = selectedPredefinedFilter != 'All' ||
                           selectedSpecialtyFilter != null ||
                           searchText.isNotEmpty;
      if (filtersActive || allDoctors.isEmpty) {
         return SliverToBoxAdapter(child: _buildEmptyListWidget(context));
      }
      // If 'All' is selected, no filters active, but list is somehow empty (edge case?)
       return const SliverToBoxAdapter(
        child: SizedBox.shrink(), // Or show a generic "No doctors available"
      );
    }

    // Build the list using filteredDoctors
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // Determine if the current doctor is a favorite
        final doctor = filteredDoctors[index];
        final bool isFavorite = userFavoriteIds.contains(doctor.id);
        return DoctorListItem(
          doctor: doctor,
          isFavoriteView: isFavorite, // Pass the favorite status (assuming DoctorListItem uses 'isFavoriteView')
          onFavoriteToggle: loggedInUserId != null ? onFavoriteToggle : null, // Pass callback
          isTogglingFavorite: togglingFavoriteIds.contains(doctor.id),
        );
      }, childCount: filteredDoctors.length),
    );
  }

  // --- Helper Widgets for List States (Copied from Home.dart) ---
  Widget _buildErrorWidget(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 50),
            const SizedBox(height: 10),
            Text(
              errorLoadingDoctors ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: errorColor, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRefresh, // Use the refresh callback for retry
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListWidget(BuildContext context) {
    final theme = Theme.of(context);
    // Message shown when filters result in an empty list or no doctors initially
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
        child: Text(
          allDoctors.isEmpty && !isLoadingDoctors // Check if master list is truly empty
              ? 'No doctors found at the moment.'
              : 'No doctors match your current filters.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: theme.disabledColor),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
      child: Center(
        child: Text(
          'You haven\'t added any favorite doctors yet.\nTap the heart icon on a doctor\'s profile to add them.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: theme.disabledColor,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
