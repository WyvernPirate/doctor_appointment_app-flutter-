// lib/models/doctor.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String address;
  final String phone;
  final String imageUrl;
  final double rating;
  final double latitude;
  final double longitude;
  final String bio;
  final bool isFavorite;
  final Map<String, String> workingHours; // e.g., {'Monday': '9 AM - 5 PM', ...}
  final List<String> availableSlots; // e.g., ['09:00', '09:30', '10:00']

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.address,
    required this.phone,
    required this.imageUrl,
    required this.rating,
    required this.bio,
    required this.latitude,
    required this.longitude,
    this.isFavorite = false,
    required this.workingHours,
    required this.availableSlots,
  });

  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    print("[Doctor.fromFirestore] Processing ID: ${doc.id}, Raw location data: ${data['location']}, Type: ${data['location']?.runtimeType}"); // Log raw data

    return Doctor(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      specialty: data['specialty'] ?? 'N/A',
      address: data['address'] ?? 'N/A',
      phone: data['phone'] ?? 'N/A',
      imageUrl: data['imageUrl'] ?? '', 
      rating: (data['rating'] ?? 0.0).toDouble(),
      bio: data['bio'] ?? 'N/A',
      // Read location: Prioritize GeoPoint, fallback to Map
      latitude: (data['location'] is GeoPoint)
          ? () {
              final geoPoint = data['location'] as GeoPoint;
              print("  -> Reading location as GeoPoint: Lat=${geoPoint.latitude}, Lng=${geoPoint.longitude}");
              return geoPoint.latitude;
            }()
          : (data['location'] is Map && data['location']['latitude'] is num)
              ? () {
                  final lat = (data['location']['latitude'] as num).toDouble();
                  print("  -> Reading location as Map: Lat=$lat");
                  return lat;
                }()
              : 0.0, // Default if missing or wrong type
      longitude: (data['location'] is GeoPoint)
          ? (data['location'] as GeoPoint).longitude // Already printed lat/lng above
          : (data['location'] is Map && data['location']['longitude'] is num)
              ? (data['location']['longitude'] as num).toDouble() // Already printed lat above, assume lng is ok
              : 0.0, // Default if missing or wrong type

      isFavorite: data['isFavorite'] ?? false,
      // Handle potential type issues from Firestore
      workingHours: Map<String, String>.from(data['workingHours'] ?? {}),
      // Handle potential type issues from Firestore
      availableSlots: List<String>.from(data['availableSlots'] ?? []),
    );
  }

  // toJson to save updates back to Firestore
  Map<String, dynamic> toJson() {
     return {
       'name': name,
       'specialty': specialty,
       'address': address,
       'phone': phone,
       'imageUrl': imageUrl,
       'rating': rating,
       'bio': bio, // Corrected key from 'reviews' to 'bio' if that was intended
       // Store location as GeoPoint
       'location': GeoPoint(latitude, longitude),
       'isFavorite': isFavorite,
       'workingHours': workingHours,
       'availableSlots': availableSlots,
     };
   }
}