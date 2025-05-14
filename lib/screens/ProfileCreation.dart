// ProfileCreation.dart
import 'dart:io';
import 'package:doctor_appointment_app/models/DatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase User
import 'Home.dart';

class ProfileCreation extends StatefulWidget {
  final User firebaseUser; // Accept Firebase User object
  const ProfileCreation({super.key, required this.firebaseUser});

  @override
  _ProfileCreationState createState() => _ProfileCreationState();
}

class _ProfileCreationState extends State<ProfileCreation> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(); // Keep this
  final _emailController = TextEditingController(); 
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  String _gender = 'Male';
  File? _profileImage;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  // ignore: unused_field
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    // Initialize the email field using the Firebase user's email
    _emailController.text = widget.firebaseUser.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }


  // --- Updated Image Picker ---
  Future<void> _pickImage() async {
    // Show a dialog or bottom sheet to choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea( // Ensure content is within safe area
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    // If a source was selected, pick the image
    if (source != null) {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null && mounted) {
          setState(() {
            _profileImage = File(pickedFile.path);
          });
        }
      } catch (e) {
        _showSnackBar("Could not pick image: $e");
      }
    }
  }

  // Save Profile Data to Firestore
  Future<void> _saveProfile() async {
    // Instantiate DatabaseHelper for local DB
    final DatabaseHelper dbHelper = DatabaseHelper();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;
        // Use Firebase UID as the document ID
        String userId = widget.firebaseUser.uid;
        DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

        if (_profileImage != null) {
          String fileName = path.basename(_profileImage!.path);
          // *** UPDATED Storage Path ***
          Reference storageReference = FirebaseStorage.instance
              .ref()
              .child('userImage/$userId/$fileName'); // Use Firebase UID in path
          UploadTask uploadTask = storageReference.putFile(_profileImage!);
          await uploadTask.whenComplete(() async {
            imageUrl = await storageReference.getDownloadURL();
          });
        }

        // Store user data in Firestore using the generated ID
        await userDocRef.set({
          'userId': userId, // Store the Firebase UID
          'name': _nameController.text,
          'email': widget.firebaseUser.email, // Use email from Firebase User
          'phone': _phoneController.text,
          'address': _addressController.text,
          'dob': _dobController.text,
          'gender': _gender,
          'profileImageUrl': imageUrl,
          // DO NOT store password or hashed password here
          // Add creation timestamp, etc. if needed
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save profile data to local database (optional)
        await dbHelper.insertUserProfile({
          'userId': userId, // Use Firebase UID
          'name': _nameController.text,
          'email': widget.firebaseUser.email ?? '',
          'phone': _phoneController.text,
          'address': _addressController.text,
          'dob': _dobController.text,
          'gender': _gender,
          'profileImageUrl': imageUrl,
        });

        // *** Store generatedUserId locally to signify login ***
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserId', userId); // Store Firebase UID
        await prefs.setBool('isGuest', false); // Explicitly set not guest

        // Navigate to Home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      } catch (e, stackTrace) {
        print('Error saving profile: $e');
        print(stackTrace);
        _showSnackBar('Error saving profile. Please try again.');
         setState(() { // Ensure loading stops on error
           _isLoading = false;
         });
      }
      // Removed finally block
    }
  }

  void _showSnackBar(String message) {
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
      appBar: AppBar(
        title: const Text('Create Your Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                   // Profile Image
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : const AssetImage('assets/profile_placeholder.png')
                                as ImageProvider, // Placeholder
                        onBackgroundImageError: (exception, stackTrace) {
                           print("Error loading image preview: $exception");
                        },
                        child: _profileImage == null
                            ? const Icon(Icons.camera_alt, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Email
                    TextFormField( // Email field
                      controller: _emailController,
                      readOnly: true, // Make email read-only here
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      
                    ),
                   const SizedBox(height: 10),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Date of Birth
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your date of birth';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Gender
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Male',
                          child: Text('Male'),
                        ),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _gender = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
