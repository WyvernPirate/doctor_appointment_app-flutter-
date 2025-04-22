// lib/screens/Appointments.dart
import 'dart:convert'; // For jsonEncode/jsonDecode

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'InitLogin.dart';

class Appointments extends StatefulWidget {
  const Appointments({super.key});

  @override
  State<Appointments> createState() => _AppointmentsState();
}

class _AppointmentsState extends State<Appointments> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true; // Start loading initially
  String? _error;
  String? _loggedInUserId;

  // Key for storing appointments in SharedPreferences
  static const String _prefsKeyAppointments = 'user_appointments_cache';

  @override
  void initState() {
    super.initState();
    _initializeAppointments(); // Call combined init function
  }

  // Combined initialization: Load local first, then fetch from network
  Future<void> _initializeAppointments() async {
    await _loadUserId(); // Ensure user ID is loaded
    if (_loggedInUserId != null) {
      await _loadLocalAppointments(); // Load cached data first
      await _loadAppointmentsFromFirestore(); // Then fetch fresh data
    } else {
      // Handle case where user ID couldn't be loaded (e.g., show login prompt)
      if (mounted) {
         setState(() {
           _error = "Please log in to view appointments.";
           _isLoading = false; // Stop loading as we can't proceed
         });
      }
    }
  }

  // Load User ID from SharedPreferences
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _loggedInUserId = prefs.getString('loggedInUserId');
    }
  }

  // --- Load Appointments from Local Storage ---
  Future<void> _loadLocalAppointments() async {
    if (!mounted || _loggedInUserId == null) return;

    // Show loading indicator while loading local data (optional, usually fast)
    // setState(() { _isLoading = true; });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? appointmentsJson = prefs.getString(_prefsKeyAppointments + _loggedInUserId!); // User-specific key

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(appointmentsJson);
        final List<Map<String, dynamic>> localAppointments = decodedList.map((item) {
          // Ensure item is a Map<String, dynamic>
          if (item is Map) {
             Map<String, dynamic> appointmentMap = Map<String, dynamic>.from(item);
             // Convert timestamp (milliseconds) back to DateTime for display consistency
             if (appointmentMap['appointmentTimeMillis'] is int) {
                appointmentMap['appointmentTime'] = DateTime.fromMillisecondsSinceEpoch(appointmentMap['appointmentTimeMillis']);
             }
             // Remove the millis version if you don't need it
             // appointmentMap.remove('appointmentTimeMillis');
             return appointmentMap;
          }
          return <String, dynamic>{}; // Return empty map if item is not a map
        }).where((map) => map.isNotEmpty).toList(); // Filter out any empty maps

        if (mounted) {
          setState(() {
            _appointments = localAppointments;
            // Keep isLoading true until Firestore fetch completes, or set false here
            // _isLoading = false; // Show cached data immediately
            _error = null; // Clear previous errors if local data loaded
          });
        }
      }
    } catch (e) {
      print("Error loading local appointments: $e");
      // Don't necessarily show error here, let Firestore fetch handle it
    }
    // Don't set isLoading to false here if you want the indicator until Firestore loads
  }

  // --- Fetch Appointments from Firestore ---
  Future<void> _loadAppointmentsFromFirestore() async {
    if (!mounted || _loggedInUserId == null) return;

    // Ensure loading indicator is shown while fetching from network
    if (!_isLoading) {
       setState(() { _isLoading = true; });
    }
    setState(() { _error = null; }); // Clear previous errors

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: _loggedInUserId)
          .orderBy('appointmentTime', descending: false)
          .get();

      if (mounted) {
        final List<Map<String, dynamic>> firestoreAppointments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          // Ensure appointmentTime is DateTime for consistent handling in UI
          if (data['appointmentTime'] is Timestamp) {
             data['appointmentTime'] = (data['appointmentTime'] as Timestamp).toDate();
          }
          return data;
        }).toList();

        setState(() {
          _appointments = firestoreAppointments; // Update with fresh data
          _isLoading = false; // Stop loading
          _error = null; // Clear error on success
        });

        // --- Save fetched data locally ---
        await _saveAppointmentsLocally(firestoreAppointments);
      }
    } catch (e) {
      print("Error fetching appointments from Firestore: $e");
      if (mounted) {
        // Only show error if local loading also failed or wasn't possible
        if (_appointments.isEmpty) {
          setState(() {
            _error = "Failed to load appointments.";
            _isLoading = false; // Stop loading on error
          });
        } else {
          // If local data exists, just stop loading but don't show error overlaying cached data
          setState(() { _isLoading = false; });
          // Optionally show a subtle snackbar error
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not refresh appointments.'), duration: Duration(seconds: 2))
          );
        }
      }
    }
  }

  // --- Save Appointments to Local Storage ---
  Future<void> _saveAppointmentsLocally(List<Map<String, dynamic>> appointments) async {
     if (!mounted || _loggedInUserId == null) return;

     try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        // Create a list suitable for JSON encoding (convert DateTime/Timestamp)
        List<Map<String, dynamic>> encodableList = appointments.map((appointment) {
           Map<String, dynamic> encodableMap = Map.from(appointment);
           // Convert DateTime or Timestamp to milliseconds since epoch
           if (encodableMap['appointmentTime'] is DateTime) {
              encodableMap['appointmentTimeMillis'] = (encodableMap['appointmentTime'] as DateTime).millisecondsSinceEpoch;
           } else if (encodableMap['appointmentTime'] is Timestamp) {
              encodableMap['appointmentTimeMillis'] = (encodableMap['appointmentTime'] as Timestamp).millisecondsSinceEpoch;
           }
           // Remove the original DateTime/Timestamp object before encoding
           encodableMap.remove('appointmentTime');
           return encodableMap;
        }).toList();

        String appointmentsJson = jsonEncode(encodableList);
        await prefs.setString(_prefsKeyAppointments + _loggedInUserId!, appointmentsJson); // User-specific key
        print("Appointments saved locally.");
     } catch (e) {
        print("Error saving appointments locally: $e");
        // Handle saving error if necessary (e.g., show a message)
     }
  }


  // Helper function to build an appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    String doctorName = appointment['doctorName'] ?? 'N/A';
    String specialty = appointment['doctorSpecialty'] ?? 'N/A';
    String status = appointment['status'] ?? 'Unknown';
    String imageUrl = appointment['doctorImageUrl'] ?? '';

    // Format the DateTime (loaded from local or converted from Firestore)
    String dateStr = 'N/A';
    String timeStr = 'N/A';
    // Check if 'appointmentTime' exists and is a DateTime object
    if (appointment['appointmentTime'] is DateTime) {
      DateTime dt = appointment['appointmentTime'] as DateTime;
      dateStr = DateFormat.yMMMd().format(dt); // e.g., Apr 23, 2025
      timeStr = DateFormat.jm().format(dt); // e.g., 10:30 AM
    }
    // Fallback check for milliseconds if DateTime conversion failed during load
    else if (appointment['appointmentTimeMillis'] is int) {
       DateTime dt = DateTime.fromMillisecondsSinceEpoch(appointment['appointmentTimeMillis']);
       dateStr = DateFormat.yMMMd().format(dt);
       timeStr = DateFormat.jm().format(dt);
    }


    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
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
                  Text(doctorName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(specialty, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Row( // Date and Time
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
                  // Status Badge
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
      body: _buildAppointmentList(),
    );
  }

  // Helper to build the list view or status messages
  Widget _buildAppointmentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Show error ONLY if appointments list is empty
    if (_error != null && _appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column( // Added Column for retry button
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
               const SizedBox(height: 10),
               ElevatedButton.icon(
                 icon: const Icon(Icons.refresh),
                 label: const Text('Retry'),
                 onPressed: _loadAppointmentsFromFirestore, // Retry fetching
               )
             ],
           ),
        ),
      );
    }
    // Show empty message if not loading, no error, and list is empty
    if (!_isLoading && _error == null && _appointments.isEmpty) {
      return RefreshIndicator( // Allow refresh even when empty
         onRefresh: _loadAppointmentsFromFirestore,
         child: LayoutBuilder( // Use LayoutBuilder to make message scrollable if needed
           builder: (context, constraints) => SingleChildScrollView(
             physics: const AlwaysScrollableScrollPhysics(),
             child: ConstrainedBox(
               constraints: BoxConstraints(minHeight: constraints.maxHeight),
               child: const Center(child: Text('No appointments scheduled yet.')),
             ),
           ),
         ),
       );
    }
    // Build the list using cached or fresh data
    return RefreshIndicator(
      onRefresh: _loadAppointmentsFromFirestore, // Reload data on pull
      child: ListView.builder(
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appointment = _appointments[index];
          return _buildAppointmentCard(appointment);
        },
      ),
    );
  }

  // Helper function to build a status badge
  Widget _buildStatusBadge(String status) {
    // ... (code remains the same) ...
     Color badgeColor;
    switch (status.toLowerCase()) {
      case 'scheduled':
        badgeColor = Colors.blue;
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
