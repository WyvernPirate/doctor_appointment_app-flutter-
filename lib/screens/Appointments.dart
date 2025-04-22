// lib/screens/Appointments.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:intl/intl.dart'; // Import intl for date formatting
// Remove DatabaseHelper import if no longer used for appointments
// import 'package:doctor_appointment_app/models/DatabaseHelper.dart';
import 'InitLogin.dart'; // For redirect if not logged in

class Appointments extends StatefulWidget {
  const Appointments({super.key});

  @override
  State<Appointments> createState() => _AppointmentsState();
}

class _AppointmentsState extends State<Appointments> {
  // Remove DatabaseHelper instance if not used elsewhere
  // final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _appointments = []; // Store fetched appointments
  bool _isLoading = true;
  String? _error;
  String? _loggedInUserId; // Store user ID

  @override
  void initState() {
    super.initState();
    _loadAppointments(); // Load appointments on init
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Get logged-in user ID
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _loggedInUserId = prefs.getString('loggedInUserId');

    if (_loggedInUserId == null) {
      // Handle case where user is not logged in (should ideally be prevented by Home screen logic)
      print("Error: No user ID found for Appointments screen.");
      if (mounted) {
        setState(() {
          _error = "Please log in to view appointments.";
          _isLoading = false;
        });
        // Optionally redirect to login
        // Future.delayed(Duration(seconds: 2), () {
        //   if (mounted) {
        //      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InitLogin()));
        //   }
        // });
      }
      return;
    }

    // --- Fetch from Firestore ---
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: _loggedInUserId) // Filter by user ID
          .orderBy('appointmentTime', descending: false) // Sort by time
          .get();

      if (mounted) {
        // Map Firestore documents to our list format
        _appointments = querySnapshot.docs.map((doc) {
          // Important: Include the document ID if you need it later (e.g., for cancellation)
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add document ID to the map
          return data;
        }).toList();

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching appointments: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load appointments.";
          _isLoading = false;
        });
      }
    }
  }

  // --- Remove Sample Data Loading ---
  // Future<void> _loadSampleAppointments() async { ... } // DELETE THIS METHOD

  // Helper function to build an appointment card using Firestore data
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    // Safely get data, provide defaults
    String doctorName = appointment['doctorName'] ?? 'N/A';
    String specialty = appointment['doctorSpecialty'] ?? 'N/A';
    String status = appointment['status'] ?? 'Unknown';
    String imageUrl = appointment['doctorImageUrl'] ?? '';

    // Format the Timestamp
    String dateStr = 'N/A';
    String timeStr = 'N/A';
    if (appointment['appointmentTime'] is Timestamp) {
      DateTime dt = (appointment['appointmentTime'] as Timestamp).toDate();
      // Use intl package for formatting
      dateStr = DateFormat.yMMMd().format(dt); // e.g., Apr 23, 2025
      timeStr = DateFormat.jm().format(dt); // e.g., 10:30 AM
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row( // Use Row for image + details
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/60?text=N/A', // Placeholder
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60, height: 60, color: Colors.grey.shade200,
                  child: Icon(Icons.person, color: Colors.grey.shade400, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Appointment Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(specialty, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Row( // Date and Time on one line
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(dateStr, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(timeStr, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Status Badge aligned to the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildStatusBadge(status),
                  ),
                  // Optional: Add Cancel Button
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(
                  //      onPressed: status == 'Scheduled' ? () { /* TODO: Handle cancellation */ } : null,
                  //      child: Text('Cancel', style: TextStyle(color: status == 'Scheduled' ? Colors.red : Colors.grey)),
                  //   ),
                  // )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Appointments'),
        centerTitle: true,
      ),
      body: _buildAppointmentList(), // Use helper for body content
    );
  }

  // Helper to build the list view or status messages
  Widget _buildAppointmentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }
    if (_appointments.isEmpty) {
      return const Center(
        child: Text('No appointments scheduled yet.'),
      );
    }
    // Use RefreshIndicator for pull-to-refresh
    return RefreshIndicator(
      onRefresh: _loadAppointments, // Reload data on pull
      child: ListView.builder(
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appointment = _appointments[index];
          return _buildAppointmentCard(appointment);
        },
      ),
    );
  }

  // Helper function to build a status badge (remains the same)
  Widget _buildStatusBadge(String status) {
    // ... (code remains the same) ...
     Color badgeColor;
    switch (status.toLowerCase()) {
      case 'scheduled': // Changed from 'confirmed' to match booking logic
        badgeColor = Colors.blue; // Use blue for scheduled
        break;
      case 'completed':
         badgeColor = Colors.green;
         break;
      case 'pending':
        badgeColor = Colors.orange;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12, // Slightly smaller badge text
        ),
      ),
    );
  }
}
