// Profile.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Map<String, dynamic> _profileData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    // Replace 'someUserId' with the actual user ID
    String userId = 'someUserId';

    try {
      // Fetch user data from Firestore
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _profileData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        // Handle case where user data is not found
        _showSnackBar('User data not found.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle errors
      print('Error fetching profile data: $e');
      _showSnackBar('Error fetching profile data.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, [String? s]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _profileData['profileImageUrl'] != null
                        ? NetworkImage(_profileData['profileImageUrl'])
                        : const AssetImage('assets/profile_placeholder.png')
                            as ImageProvider,
                  ),
                  const SizedBox(height: 20),

                  // Name
                  Text(
                    _profileData['name'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Email
                  _buildProfileInfoRow(
                      Icons.email, _profileData['email'] ?? 'N/A'),
                  const SizedBox(height: 10),

                  // Phone
                  _buildProfileInfoRow(
                      Icons.phone, _profileData['phone'] ?? 'N/A'),
                  const SizedBox(height: 10),

                  // Address
                  _buildProfileInfoRow(
                      Icons.location_on, _profileData['address'] ?? 'N/A'),
                  const SizedBox(height: 10),

                  // Date of Birth
                  _buildProfileInfoRow(
                      Icons.calendar_today, _profileData['dob'] ?? 'N/A'),
                  const SizedBox(height: 10),

                  // Gender
                  _buildProfileInfoRow(
                      Icons.person, _profileData['gender'] ?? 'N/A'),
                  const SizedBox(height: 20),

                  // Edit Profile Button (Placeholder)
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to edit profile screen later
                      _showSnackBar(
                          context as String, 'Edit Profile button pressed');
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
}
