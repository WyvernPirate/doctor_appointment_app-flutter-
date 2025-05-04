// lib/widgets/doctor_list_item.dart
import 'package:flutter/material.dart';
import '/models/doctor.dart';
import '/screens/DoctorDetails.dart';

class DoctorListItem extends StatelessWidget {
  final Doctor doctor;
  final bool isFavoriteView;
  final Function(String doctorId, bool isCurrentlyFavorite)? onFavoriteToggle;
  final bool isTogglingFavorite;

  const DoctorListItem({
    super.key,
    required this.doctor,
    this.isFavoriteView = false,
    this.onFavoriteToggle,
    this.isTogglingFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    // --- Get Theme Data ---
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final cardTheme = theme.cardTheme;

    // --- Define Styles using Theme ---

    final TextStyle nameStyle =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 17, fontWeight: FontWeight.bold);

    final TextStyle detailStyle =
        textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant) ??
        TextStyle(fontSize: 13, color: Colors.grey.shade700);

    final TextStyle separatorStyle =
        textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        ) ??
        TextStyle(fontSize: 13, color: Colors.grey.shade500);

    final TextStyle ratingStyle =
        textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant) ??
        TextStyle(fontSize: 13, color: Colors.grey.shade600);

    // --- Conditional Border for Favorite View ---
    final BorderSide favoriteBorderSide =
        isFavoriteView
            ? BorderSide(
              color: colorScheme.primary.withOpacity(0.6),
              width: 1.5,
            )
            : BorderSide.none;

    // --- Build Widget ---
    return Card(
      shape:
          (cardTheme.shape as RoundedRectangleBorder?)?.copyWith(
            side: favoriteBorderSide,
          ) ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), 
            side: favoriteBorderSide,
          ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorDetails(doctorId: doctor.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Doctor Image ---
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  // Use a placeholder asset
                  doctor.imageUrl.isNotEmpty
                      ? doctor.imageUrl
                      : 'https://via.placeholder.com/80?text=No+Image',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      // Placeholder while loading
                      width: 80,
                      height: 80,
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline,
                          color: colorScheme.onSurfaceVariant,
                          size: 40,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 15),

              // --- Doctor Info Column ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      doctor.name,
                      style: nameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Specialty | Address Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            doctor.specialty,
                            style: detailStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Separator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text('|', style: separatorStyle),
                        ),

                        Expanded(
                          child: Text(
                            doctor.address.isNotEmpty ? doctor.address : 'N/A',
                            style: detailStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Rating Row
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          doctor.rating.toStringAsFixed(1),
                          style: ratingStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- Favorite Icon Button ---
              if (onFavoriteToggle != null)
                isTogglingFavorite
                    ? Container(
                      // Loading indicator
                      padding: const EdgeInsets.all(12.0),
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                    : IconButton(
                      // Heart button
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isFavoriteView // Use the passed-in state
                            ? Icons.favorite
                            : Icons.favorite_border,
                        // Red for favorite, default otherwise
                        color:
                            isFavoriteView // Use the passed-in state
                                ? Colors.redAccent
                                : colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      tooltip:
                          isFavoriteView // Use the passed-in state
                              ? 'Remove from Favorites'
                              : 'Add to Favorites',
                      onPressed:
                          () => onFavoriteToggle!(doctor.id, isFavoriteView), // Pass the correct current state
                      splashRadius: 24,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
