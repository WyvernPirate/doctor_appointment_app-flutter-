// Profile.dart
import 'package:flutter/material.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Sample profile data (replace with data from Firebase later)
  Map<String, String> _profileData = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
    'phone': '+1-555-123-4567',
    'address': '123 Main St, Anytown, USA',
    'dob': '1990-01-15',
    'gender': 'Male',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture (Placeholder)
            const CircleAvatar(
              radius: 60,
             // backgroundImage: AssetImage('assets/profile_placeholder.png'), // Replace with actual image path or network image
              // You can use NetworkImage here when you fetch the image from Firebase
              // backgroundImage: NetworkImage(_profileData['profileImageUrl'] ?? ''),
            ),
            const SizedBox(height: 20),

            // Name
            Text(
              _profileData['name']!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Email
            _buildProfileInfoRow(Icons.email, _profileData['email']!),
            const SizedBox(height: 10),

            // Phone
            _buildProfileInfoRow(Icons.phone, _profileData['phone']!),
            const SizedBox(height: 10),

            // Address
            _buildProfileInfoRow(Icons.location_on, _profileData['address']!),
            const SizedBox(height: 10),

            // Date of Birth
            _buildProfileInfoRow(Icons.calendar_today, _profileData['dob']!),
            const SizedBox(height: 10),

            // Gender
            _buildProfileInfoRow(Icons.person, _profileData['gender']!),
            const SizedBox(height: 20),

            // Edit Profile Button (Placeholder)
            ElevatedButton(
              onPressed: () {
                // Navigate to edit profile screen later
                _showSnackBar(context, 'Edit Profile button pressed');
              },
              child: const Text('Edit Profile'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build a row for profile information
  Widget _buildProfileInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  // Helper function to show a snackbar
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
