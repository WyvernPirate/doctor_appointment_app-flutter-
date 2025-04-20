// lib/screens/Profile.dart
import '/models/DatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import InitLogin if you need it for navigation after deletion
// import 'InitLogin.dart';

// Enum to represent profile settings actions
enum ProfileAction {
  editProfile,
  appearance,
  location,
  deleteAccount,
}

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Map<String, dynamic> _profileData = {};
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> _fetchProfileData() async {
    if (mounted) {
      setState(() { _isLoading = true; });
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('loggedInUserId');

    if (_userId == null) {
      print("Error: No loggedInUserId found in SharedPreferences for Profile screen.");
      if (mounted) {
        _showSnackBar('Could not load profile. Please log in again.');
        setState(() { _isLoading = false; });
      }
      return;
    }

    try {
      // Fetch from local database first (optional optimization)
      Map<String, dynamic>? localProfile = await _dbHelper.getUserProfile(_userId!);
      if (localProfile != null && mounted) {
        setState(() {
          _profileData = localProfile;
          _isLoading = false;
        });
        // Optionally trigger a background fetch from Firebase to update local cache
        // _fetchFromFirebaseAndUpdateLocal();
        return;
      }

      // Fetch from Firebase if not found locally or if forced refresh
      await _fetchFromFirebaseAndUpdateLocal();

    } catch (e) {
      print('Error fetching profile data: $e');
      if (mounted) {
        _showSnackBar('Error fetching profile data.');
        setState(() { _isLoading = false; });
      }
    }
  }

  // Helper to fetch from Firebase and update local DB
  Future<void> _fetchFromFirebaseAndUpdateLocal() async {
     if (_userId == null) return; // Should not happen if called after initial check

     try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId!)
            .get();

        if (userDoc.exists && mounted) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _profileData = data;
            _isLoading = false; // Ensure loading stops after fetch
          });
          // Update local database in the background
          await _dbHelper.insertUserProfile(data);
        } else if (mounted) {
          _showSnackBar('User data not found in database.');
          setState(() { _isLoading = false; });
        }
     } catch (e) {
        print('Error fetching from Firebase: $e');
        // Don't necessarily show snackbar here if local data was already loaded
        if (mounted && _profileData.isEmpty) { // Show error only if we have no data at all
           _showSnackBar('Error fetching profile data from server.');
           setState(() { _isLoading = false; });
        } else if (mounted) {
           // If local data exists, just ensure loading is false
           setState(() { _isLoading = false; });
        }
     }
  }


  void _showSnackBar(String message) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10), // Add some margin
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners
      ),
    );
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use AppBar only if not nested within another Scaffold with AppBar
      // If Profile is a tab in Home, Home's AppBar might be sufficient
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color, // Inherit text color
        // --- Updated Actions Section ---
        actions: [
          // Show settings menu only when profile is loaded and not empty
          if (!_isLoading && _profileData.isNotEmpty)
            PopupMenuButton<ProfileAction>(
              icon: Icon(
                Icons.settings_outlined,
                color: Theme.of(context).iconTheme.color, // Use theme icon color
              ),
              tooltip: 'Settings',
              onSelected: _handleProfileAction, // Callback function for selection
              itemBuilder: (BuildContext context) => <PopupMenuEntry<ProfileAction>>[
                // Edit Profile Option
                const PopupMenuItem<ProfileAction>(
                  value: ProfileAction.editProfile,
                  child: ListTile( // Use ListTile for icon + text
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Profile'),
                    dense: true,
                    contentPadding: EdgeInsets.zero, // Adjust padding
                  ),
                ),
                // Appearance Option
                const PopupMenuItem<ProfileAction>(
                  value: ProfileAction.appearance,
                  child: ListTile(
                    leading: Icon(Icons.palette_outlined),
                    title: Text('Appearance'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                // Location Option
                const PopupMenuItem<ProfileAction>(
                  value: ProfileAction.location,
                  child: ListTile(
                    leading: Icon(Icons.location_on_outlined),
                    title: Text('Location Settings'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(), // Optional separator
                // Delete Account Option
                PopupMenuItem<ProfileAction>(
                  value: ProfileAction.deleteAccount,
                  child: ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700), // Warning color
                    title: Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red.shade700), // Warning color
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8), // Add padding to the right of the button
        ],
      ),
      body: _buildProfileBody(), // Extracted body logic
    );
  }

  // --- Helper to Build Body Content ---
  Widget _buildProfileBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profileData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column( // Use Column for text and retry button
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.error_outline, color: Colors.grey, size: 50),
               const SizedBox(height: 10),
               const Text(
                 'Could not load profile data. Please try again later or log back in.',
                 textAlign: TextAlign.center,
                 style: TextStyle(fontSize: 16, color: Colors.grey),
               ),
               const SizedBox(height: 20),
               ElevatedButton.icon(
                 icon: const Icon(Icons.refresh),
                 label: const Text('Retry'),
                 onPressed: _fetchProfileData,
               )
             ],
           ),
        ),
      );
    }

    // --- Main Profile Content ---
    return RefreshIndicator( // Optional: Add pull-to-refresh
      onRefresh: _fetchProfileData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll even if content fits
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Adjust top padding
        child: Column(
          children: [
            // --- Profile Header Section ---
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // --- Profile Details Section (Using Card and ListTiles) ---
            _buildProfileDetailsCard(),

            // Optional: Add other sections like 'My Activity', 'Settings Shortcut', etc.
            // const SizedBox(height: 24),
            // _buildOtherSections(),
          ],
        ),
      ),
    );
  }

  // --- Helper for Profile Header (Avatar and Name) ---
  Widget _buildProfileHeader() {
    String? imageUrl = _profileData['profileImageUrl'];
    ImageProvider<Object> backgroundImage =
        const AssetImage('assets/profile_placeholder.png'); // Default placeholder

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Basic validation: Check if it looks like a URL
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
         backgroundImage = NetworkImage(imageUrl);
      } else {
         print("Warning: profileImageUrl does not seem to be a valid URL: $imageUrl");
         // Keep the placeholder if the URL format is suspicious
      }
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: backgroundImage,
          onBackgroundImageError: (exception, stackTrace) {
            print("Error loading profile image: $exception");
            // Optionally set state to show placeholder if error occurs,
            // but backgroundImage already defaults to placeholder
          },
          child: Container(
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(
                 color: Theme.of(context).primaryColor.withOpacity(0.5),
                 width: 2.0,
               ),
             ),
           ),
        ),
        const SizedBox(height: 16),
        Text(
          _profileData['name'] ?? 'N/A',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        // Optional: Add email below name if desired and available
        if (_profileData['email'] != null && _profileData['email'].isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _profileData['email'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // --- Helper for Profile Details Card ---
  Widget _buildProfileDetailsCard() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            // Only show email if available
            if (_profileData['email'] != null && _profileData['email'].isNotEmpty) ...[
              _buildInfoListTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: _profileData['email'],
              ),
              _buildDivider(),
            ],
            _buildInfoListTile(
              icon: Icons.phone_outlined,
              title: 'Phone',
              subtitle: _profileData['phone'] ?? 'Not Provided',
            ),
             _buildDivider(),
            _buildInfoListTile(
              icon: Icons.location_on_outlined,
              title: 'Address',
              subtitle: _profileData['address'] ?? 'Not Provided',
              isMultiline: true,
            ),
             _buildDivider(),
            _buildInfoListTile(
              icon: Icons.calendar_today_outlined,
              title: 'Date of Birth',
              subtitle: _profileData['dob'] ?? 'Not Provided',
            ),
             _buildDivider(),
            _buildInfoListTile(
              icon: Icons.person_outline,
              title: 'Gender',
              subtitle: _profileData['gender'] ?? 'Not Provided',
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable ListTile Builder ---
  Widget _buildInfoListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isMultiline = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      ),
      subtitle: Text(
        subtitle.isEmpty ? 'Not Provided' : subtitle, // Handle empty strings
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: isMultiline ? 1.4 : 1.2, // Adjust line height
        ),
      ),
      dense: true,
      isThreeLine: isMultiline && subtitle.length > 35, // Adjust threshold for three lines
    );
  }

  // --- Reusable Divider ---
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey.shade200,
    );
  }

  // --- Handle Settings Menu Selection ---
  void _handleProfileAction(ProfileAction selectedAction) {
    switch (selectedAction) {
      case ProfileAction.editProfile:
        // TODO: Navigate to Edit Profile Screen
        // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(profileData: _profileData)));
        _showSnackBar('Edit Profile selected (Not Implemented)');
        break;
      case ProfileAction.appearance:
        // TODO: Navigate to Appearance Settings Screen or show a dialog
        // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceSettingsScreen()));
        _showSnackBar('Appearance selected (Not Implemented)');
        break;
      case ProfileAction.location:
        // TODO: Navigate to Location Settings Screen or manage permissions
        // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => LocationSettingsScreen()));
        _showSnackBar('Location Settings selected (Not Implemented)');
        break;
      case ProfileAction.deleteAccount:
        _showDeleteConfirmationDialog(); // Show confirmation first
        break;
    }
  }

  // --- Example Delete Confirmation Dialog ---
  Future<void> _showDeleteConfirmationDialog() async {
    if (!mounted) return;

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you absolutely sure you want to delete your account?'),
                SizedBox(height: 10),
                Text(
                  'This action is irreversible and all your data associated with this account will be permanently lost.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('DELETE'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      // User confirmed deletion
      _performAccountDeletion(); // Call the actual deletion logic
    } else {
      // User cancelled
      _showSnackBar('Account deletion cancelled.');
    }
  }

  // --- Actual Account Deletion Logic ---
  Future<void> _performAccountDeletion() async {
     if (!mounted || _userId == null) return;

     // Show loading indicator (optional, but good UX)
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (context) => const Center(child: CircularProgressIndicator()),
     );

     try {
       // 1. Delete Firestore data (add other collections if needed)
       await FirebaseFirestore.instance.collection('users').doc(_userId!).delete();
       // Example: Delete related appointments
       // QuerySnapshot appointments = await FirebaseFirestore.instance.collection('appointments').where('userId', isEqualTo: _userId!).get();
       // WriteBatch batch = FirebaseFirestore.instance.batch();
       // for (var doc in appointments.docs) {
       //   batch.delete(doc.reference);
       // }
       // await batch.commit();

       // 2. Delete Firebase Auth user (IMPORTANT - Requires re-authentication usually)
       // This part is complex and often requires the user to re-authenticate first.
       // For simplicity here, we'll skip the actual Firebase Auth deletion,
       // but in a real app, you'd handle this, possibly by prompting for password again.
       // await FirebaseAuth.instance.currentUser?.delete();

       // 3. Clear local data
       SharedPreferences prefs = await SharedPreferences.getInstance();
       await prefs.remove('loggedInUserId');
       await prefs.setBool('isGuest', false); // Reset guest status
       await _dbHelper.deleteUserProfile(_userId!); // Delete from local DB

       if (!mounted) return;
       Navigator.of(context).pop(); // Dismiss loading indicator

       _showSnackBar('Account deleted successfully.');

       // 4. Navigate user away (e.g., to login screen)
       // Make sure InitLogin is imported if you use this
       // Navigator.of(context).pushAndRemoveUntil(
       //   MaterialPageRoute(builder: (context) => const InitLogin()),
       //   (Route<dynamic> route) => false,
       // );

       // Alternatively, just pop the profile screen if appropriate
       if (Navigator.canPop(context)) {
         Navigator.pop(context);
         // You might need to trigger a state update on the previous screen (e.g., Home)
       }


     } catch (e) {
       print("Error deleting account: $e");
       if (!mounted) return;
       Navigator.of(context).pop(); // Dismiss loading indicator
       _showSnackBar('Error deleting account: ${e.toString()}');
     }
  }

} // End of _ProfileState
