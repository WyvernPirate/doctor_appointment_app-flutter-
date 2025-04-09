// Profile.dart
import '/models/DatabaseHelper.dart';
// Remove firebase_auth import
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Map<String, dynamic> _profileData = {};
  bool _isLoading = true;
  String? _userId; // Store the user ID fetched from prefs

  @override
  void initState() {
    super.initState();
    _fetchProfileData(); // Call the async function
  }

  final DatabaseHelper _dbHelper = DatabaseHelper(); // Create an instance

  Future<void> _fetchProfileData() async {
    setState(() { _isLoading = true; }); // Start loading

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('loggedInUserId'); // Get user ID from SharedPreferences

    if (_userId == null) {
      // This case shouldn't ideally happen if navigation is correct,
      // but handle it defensively.
      print("Error: No loggedInUserId found in SharedPreferences for Profile screen.");
      _showSnackBar('Could not load profile. Please log in again.');
      setState(() { _isLoading = false; });
      // Optionally navigate back to login
      // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const InitLogin()));
      return;
    }

    try {
      // Fetch from local database first using the fetched userId
      Map<String, dynamic>? localProfile = await _dbHelper.getUserProfile(_userId!);
      if (localProfile != null && mounted) { // Check if mounted before setState
        setState(() {
          _profileData = localProfile;
          _isLoading = false;
        });
        return; // Data found locally
      }

      // Fetch from Firebase if not found locally, using the fetched userId
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId!) // Use the userId from SharedPreferences
          .get();

      if (userDoc.exists && mounted) { // Check if mounted before setState
        setState(() {
          _profileData = userDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
        // Save to local database for offline use
        await _dbHelper.insertUserProfile(_profileData);
      } else if (mounted) {
        // Handle case where user data is not found in Firestore
        _showSnackBar('User data not found in database.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle errors
      print('Error fetching profile data: $e');
      if (mounted) { // Check if mounted before setState
        _showSnackBar('Error fetching profile data.');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
     // Add mounted check for safety
     if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- UI remains the same, using _profileData ---
    return Scaffold(
      // Added AppBar for consistency, optional
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData.isEmpty // Handle case where data wasn't loaded
              ? const Center(child: Text('Could not load profile data.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Picture
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileData['profileImageUrl'] != null && _profileData['profileImageUrl'].isNotEmpty
                            ? NetworkImage(_profileData['profileImageUrl'])
                            : const AssetImage('assets/profile_placeholder.png')
                                as ImageProvider,
                        onBackgroundImageError: (_, __) { // Handle image loading errors
                          print("Error loading profile image from ${_profileData['profileImageUrl']}");
                        },
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
                          _showSnackBar('Edit Profile functionality not implemented yet.');
                        },
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Helper function - remains the same
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
