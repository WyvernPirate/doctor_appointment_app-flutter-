// lib/models/doctor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Keep if location is still used elsewhere

class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String address;
  final String phone;
  final String imageUrl;
  final double rating;
  final int reviews;
  final LatLng? location; // Keep if needed for details page, otherwise remove
  final bool isFavorite; // <-- Add this field

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.address,
    required this.phone,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    this.location,
    this.isFavorite = false, // Default to false
  });

  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle potential GeoPoint for location
    LatLng? loc;
    if (data['location'] is GeoPoint) {
      GeoPoint point = data['location'];
      loc = LatLng(point.latitude, point.longitude);
    }

    return Doctor(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      specialty: data['specialty'] ?? 'N/A',
      address: data['address'] ?? 'N/A',
      phone: data['phone'] ?? 'N/A',
      imageUrl: data['imageUrl'] ?? '', // Provide default empty string
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviews: data['reviews'] ?? 0,
      location: loc,
      isFavorite: data['isFavorite'] ?? false, // <-- Get from Firestore or default
    );
  }

  // Add toJson if you need to save updates back to Firestore
  Map<String, dynamic> toJson() {
     return {
       'name': name,
       'specialty': specialty,
       'address': address,
       'phone': phone,
       'imageUrl': imageUrl,
       'rating': rating,
       'reviews': reviews,
       'location': location != null ? GeoPoint(location!.latitude, location!.longitude) : null,
       'isFavorite': isFavorite,
     };
   }
}
