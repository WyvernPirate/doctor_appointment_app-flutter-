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

    return Doctor(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      specialty: data['specialty'] ?? 'N/A',
      address: data['address'] ?? 'N/A',
      phone: data['phone'] ?? 'N/A',
      imageUrl: data['imageUrl'] ?? '', 
      rating: (data['rating'] ?? 0.0).toDouble(),
      bio: data['bio'] ?? 'N/A',
      latitude: data['location']?['latitude'] ?? 0.0,
      longitude: data['location']?['longitude'] ?? 0.0,
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
       'location': { // Store location as a nested map (GeoPoint is also an option)
         'latitude': latitude,
         'longitude': longitude,
       },
       'isFavorite': isFavorite,
       'workingHours': workingHours,
       'availableSlots': availableSlots,
     };
   }
}