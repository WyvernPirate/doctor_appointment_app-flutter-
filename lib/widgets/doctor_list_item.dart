// lib/widgets/doctor_list_item.dart
import 'package:flutter/material.dart';
import '/screens/DoctorDetails.dart';
import '/models/doctor.dart';
// Import Doctor Details Screen if you have one
// import '/screens/DoctorDetails.dart';

class DoctorListItem extends StatelessWidget {
  final Doctor doctor;
  final bool isFavoriteView; // Flag to indicate if it's in the favorite list

  const DoctorListItem({
    super.key,
    required this.doctor,
    this.isFavoriteView = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    // Define text styles for reuse
    final TextStyle nameStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.bold);
    final TextStyle detailStyle = TextStyle(fontSize: 13, color: Colors.grey.shade700);
    final TextStyle separatorStyle = TextStyle(fontSize: 13, color: Colors.grey.shade500);
    final TextStyle ratingStyle = TextStyle(fontSize: 13, color: Colors.grey.shade600);

    return InkWell( // Make item tappable
      onTap: () {
        // --- MODIFIED NAVIGATION ---
        Navigator.push(
          context,
          MaterialPageRoute(
            // Pass the doctor's ID to the details screen
            builder: (context) => DoctorDetails(doctorId: doctor.id),
          ),
        );
        // --- END MODIFICATION ---

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Tapped on ${doctor.name} (Details not implemented)'))
        // );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
          border: isFavoriteView
              ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.6), width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
          children: [
            // Doctor Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                doctor.imageUrl.isNotEmpty ? doctor.imageUrl : 'https://via.placeholder.com/80?text=No+Image', // Placeholder URL
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.person, color: Colors.grey.shade400, size: 40),
                ),
              ),
            ),
            const SizedBox(width: 15),

            // Doctor Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Name
                  Text(
                    doctor.name,
                    style: nameStyle,
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4), 

                  // 2. Specialty | Address Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text tops
                    children: [
                      // Specialty (limit lines/overflow)
                      Flexible( // Allow specialty to shrink if needed
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
                      // Address (
                      Expanded(
                        child: Text(
                          doctor.address.isNotEmpty ? doctor.address : 'N/A', // Handle empty address
                          style: detailStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // Space before rating

                  // 3. Rating Row (Unchanged)
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${doctor.rating.toStringAsFixed(1)}',
                        style: ratingStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // --- End Doctor Info Column ---

            // Optional: Favorite Icon (Unchanged)
            if (!isFavoriteView)
              IconButton(
                padding: EdgeInsets.zero, 
                constraints: const BoxConstraints(), 
                icon: Icon(
                  doctor.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: doctor.isFavorite ? Colors.redAccent : Colors.grey,
                  size: 22,
                ),
                tooltip: doctor.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                onPressed: () {
                  // TODO: Implement favorite toggle logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Favorite toggle for ${doctor.name} (Not implemented)'))
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
