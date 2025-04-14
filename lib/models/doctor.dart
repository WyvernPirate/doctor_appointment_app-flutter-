// lib/models/doctor.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String id; // Firestore document ID
  final String name;
  final String specialty;
  final String imageUrl; // URL for the doctor's image
  final double rating; // Optional: Example field
  final String bio; // Optional: Example field

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.imageUrl,
    this.rating = 0.0, // Default value
    this.bio = '', // Default value
  });

  //constructor to create a Doctor instance from a Firestore document
  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Doctor(
      id: doc.id,
      name: data['name'] ?? 'Unknown Name', // Provide default values
      specialty: data['specialty'] ?? 'Unknown Specialty',
      imageUrl: data['imageUrl'] ?? '', // Handle missing image URL
      rating: (data['rating'] ?? 0.0).toDouble(), // Ensure it's a double
      bio: data['bio'] ?? '',
    );
  }

  // Optional: Method to convert Doctor instance to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialty': specialty,
      'imageUrl': imageUrl,
      'rating': rating,
      'bio': bio,
    };
  }
}
