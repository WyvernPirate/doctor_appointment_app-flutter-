// lib/screens/EditProfile.dart
import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'package:path/path.dart' as p; 

class EditProfile extends StatefulWidget {
  final Map<String, dynamic> initialProfileData;

  const EditProfile({super.key, required this.initialProfileData});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _dobController;
  // late TextEditingController _genderController; // Replaced by dropdown state
  // Email is typically not editable after signup, so we won't include it here.

  DateTime? _selectedDate; // State for Date Picker
  String? _selectedGender; // State for Dropdown
  XFile? _imageFile; // State for selected image file
  String? _profileImageUrl; // State for current/new image URL

  bool _isSaving = false;
  String? _userId;
  bool _isUploading = false; // State for image upload indicator

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfileData['name'] ?? '');
    _phoneController = TextEditingController(text: widget.initialProfileData['phone'] ?? '');
    _addressController = TextEditingController(text: widget.initialProfileData['address'] ?? '');
    _profileImageUrl = widget.initialProfileData['profileImageUrl']; // Load initial image URL

    // Initialize DOB
    final initialDobString = widget.initialProfileData['dob'] ?? '';
    _dobController = TextEditingController(text: initialDobString);
    if (initialDobString.isNotEmpty) {
      _selectedDate = _parseDate(initialDobString); // Try parsing initial date
    }

    // Initialize Gender
    _selectedGender = widget.initialProfileData['gender'];
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userId = prefs.getString('loggedInUserId');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    // _genderController.dispose(); // No longer used
    super.dispose();
  }

  // Helper to parse date string (adjust format if needed)
  DateTime? _parseDate(String dateString) {
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(dateString);
    } catch (e) {
      print("Error parsing date '$dateString': $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_userId == null) {
      _showSnackBar('Error: User not identified.', isError: true);
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() { _isSaving = true; });

      String? uploadedImageUrl = _profileImageUrl; // Start with existing URL

      // --- Upload new image if selected ---
      if (_imageFile != null) {
        setState(() { _isUploading = true; }); // Show upload indicator
        try {
          uploadedImageUrl = await _uploadImage(_imageFile!);
        } catch (e) {
          _showSnackBar('Failed to upload image: ${e.toString()}', isError: true);
          setState(() { _isSaving = false; _isUploading = false; }); // Stop saving on upload error
          return;
        } finally {
           if (mounted) setState(() { _isUploading = false; }); // Hide upload indicator
        }
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'dob': _dobController.text.trim(), // Save formatted date string
        'gender': _selectedGender, // Save selected gender
        if (uploadedImageUrl != null) 'profileImageUrl': uploadedImageUrl, // Add image URL if available/uploaded
      };

      try {
        await FirebaseFirestore.instance.collection('users').doc(_userId!).update(updatedData);

        if (mounted) {
          _showSnackBar('Profile updated successfully!');
          // Pass back 'true' to indicate success
          Navigator.pop(context, true);
        }
      } catch (e) {
        print("Error updating profile: $e");
        if (mounted) {
          _showSnackBar('Failed to update profile: ${e.toString()}', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() { _isSaving = false; });
        }
      }
    }
  }

  // --- Image Picking ---
  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, // Or ImageSource.camera
        imageQuality: 70, // Adjust quality as needed
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = pickedFile;
          // Optionally update _profileImageUrl immediately for preview, but FileImage is better
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      _showSnackBar('Could not pick image: ${e.toString()}', isError: true);
    }
  }

  // --- Image Uploading ---
  Future<String?> _uploadImage(XFile imageFile) async {
    if (_userId == null) throw Exception("User ID not available for upload.");

    String fileExtension = p.extension(imageFile.path); // Get file extension (e.g., '.jpg')
    String fileName = '$_userId$fileExtension'; // Use user ID as filename
    Reference storageRef = FirebaseStorage.instance.ref().child('userimages/$fileName');

    UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Date Picker ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900), // Adjust range as needed
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked); // Format for display and saving
      });
    }
  }

  // --- Gender Options ---
  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          // Save Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving || _isUploading // Show indicator if saving or uploading
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : IconButton(
                    icon: const Icon(Icons.save_outlined),
                    tooltip: 'Save Changes',
                    onPressed: _saveProfile,
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // --- Profile Picture ---
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    // Show picked file preview if available, otherwise show network/placeholder
                    backgroundImage: _imageFile != null
                        ? FileImage(File(_imageFile!.path))
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                            ? NetworkImage(_profileImageUrl!)
                            : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
                    onBackgroundImageError: _imageFile == null ? (exception, stackTrace) {
                      print("Error loading network profile image: $exception");
                      // Optionally show placeholder icon on error
                    } : null, // Don't handle error for FileImage
                  ),
                  // Edit Icon Button
                  Material(
                    color: Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: _selectImage,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                // Add validation if needed
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                maxLines: 3,
                // Add validation if needed
              ),
              const SizedBox(height: 16),
              // --- Date of Birth Picker ---
              TextFormField(
                controller: _dobController, // Displays the selected date
                decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)', border: OutlineInputBorder()),
                readOnly: true, // Prevent manual text input
                onTap: () => _selectDate(context), // Show picker on tap
              ),
              const SizedBox(height: 16),
              // --- Gender Dropdown ---
              DropdownButtonFormField<String>(
                value: _selectedGender, // Current value
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                items: _genderOptions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
                // Optional validation
                validator: (value) => value == null || value.isEmpty ? 'Please select your gender' : null,
                // Handle case where initial value might not be in options
                onTap: () {
                  // Ensure the initial value is valid or reset if not
                  if (_selectedGender != null && !_genderOptions.contains(_selectedGender)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) setState(() => _selectedGender = null);
                    });
                  }
                },
              ),
              const SizedBox(height: 30),
              // Consider adding profile picture upload here later
            ],
          ),
        ),
      ),
    );
  }
}