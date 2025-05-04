// lib/screens/Appointments.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Appointments extends StatefulWidget {
  const Appointments({super.key});

  @override
  State<Appointments> createState() => _AppointmentsState();
}

class _AppointmentsState extends State<Appointments> {
  // State variables
  List<Map<String, dynamic>> _appointments = []; // Holds ALL fetched/cached appointments
  // Lists for categorized display
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = [];
  List<Map<String, dynamic>> _cancelledAppointments = [];

  bool _isLoading = true;
  String? _error;
  String? _loggedInUserId;
  // Set to keep track of which appointment is currently being cancelled
  final Set<String> _cancellingAppointmentIds = {};

  static const String _prefsKeyAppointments = 'user_appointments_cache';

  @override
  void initState() {
    super.initState();
    _initializeAppointments();
  }

  Future<void> _initializeAppointments() async {
    await _loadUserId();
    if (_loggedInUserId != null) {
      await _loadLocalAppointments(); // Attempt to load cached data first
      await _loadAppointmentsFromFirestore(); // Fetch fresh data
    } else {
      // Handle user not logged in
      if (mounted) {
         setState(() {
           _error = "Please log in to view appointments.";
           _isLoading = false;
         });
      }
    }
  }

  // Loads the logged-in user's ID from SharedPreferences
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _loggedInUserId = prefs.getString('loggedInUserId');
    }
  }

  // Loads appointments from local SharedPreferences cache
  Future<void> _loadLocalAppointments() async {
    if (!mounted || _loggedInUserId == null) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? appointmentsJson = prefs.getString(_prefsKeyAppointments + _loggedInUserId!);

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(appointmentsJson);
        final List<Map<String, dynamic>> localAppointments = decodedList.map((item) {
          if (item is Map) {
             Map<String, dynamic> appointmentMap = Map<String, dynamic>.from(item);
             // Convert stored milliseconds back to DateTime
             if (appointmentMap['appointmentTimeMillis'] is int) {
                appointmentMap['appointmentTime'] = DateTime.fromMillisecondsSinceEpoch(appointmentMap['appointmentTimeMillis']);
             }
             return appointmentMap;
          }
          return <String, dynamic>{}; // Return empty map for invalid items
        }).where((map) => map.isNotEmpty).toList(); // Filter out invalid items

        if (mounted) {
          setState(() {
            _appointments = localAppointments; // Update main list with cached data
            _error = null; // Clear previous errors
          });
          _categorizeAppointments(); // Categorize the loaded data
        }
      }
    } catch (e) {
      print("Error loading local appointments: $e");
      // Optionally clear cache if corrupted
      // SharedPreferences prefs = await SharedPreferences.getInstance();
      // await prefs.remove(_prefsKeyAppointments + _loggedInUserId!);
    }
  }

  // Fetches appointments from Firestore for the logged-in user
  Future<void> _loadAppointmentsFromFirestore() async {
    if (!mounted || _loggedInUserId == null) return;
    // Ensure loading indicator is shown if not already loading
    if (!_isLoading) {
       setState(() { _isLoading = true; });
    }
    setState(() { _error = null; }); // Clear previous errors

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: _loggedInUserId)
          // Fetch ALL appointments (including cancelled)
          .orderBy('appointmentTime', descending: false) // Sort by time
          .get();

      if (mounted) {
        final List<Map<String, dynamic>> firestoreAppointments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Store the document ID
          // Convert Firestore Timestamp to DateTime
          if (data['appointmentTime'] is Timestamp) {
             data['appointmentTime'] = (data['appointmentTime'] as Timestamp).toDate();
          }
          return data;
        }).toList();

        setState(() {
          _appointments = firestoreAppointments; // Update main list with fresh data
          _isLoading = false; // Stop loading
          _error = null; // Clear error on success
        });
        _categorizeAppointments(); // Categorize the newly fetched data
        await _saveAppointmentsLocally(_appointments); // Save the full list locally
      }
    } catch (e) {
      print("Error fetching appointments from Firestore: $e");
      if (mounted) {
        // Show error only if no data (neither local nor fetched) could be displayed
        if (_appointments.isEmpty) {
          setState(() {
            _error = "Failed to load appointments.";
            _isLoading = false; // Stop loading on error
          });
        } else {
          // If local data exists, just stop loading but show a less intrusive error
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not refresh appointments.'), duration: Duration(seconds: 2))
          );
        }
      }
    }
  }

  // Saves the current list of appointments to SharedPreferences
  Future<void> _saveAppointmentsLocally(List<Map<String, dynamic>> appointments) async {
     if (!mounted || _loggedInUserId == null) return;
     try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        // Convert DateTime objects to milliseconds for JSON compatibility
        List<Map<String, dynamic>> encodableList = appointments.map((appointment) {
           Map<String, dynamic> encodableMap = Map.from(appointment);
           if (encodableMap['appointmentTime'] is DateTime) {
              encodableMap['appointmentTimeMillis'] = (encodableMap['appointmentTime'] as DateTime).millisecondsSinceEpoch;
           }
           // Remove the original DateTime object before encoding
           encodableMap.remove('appointmentTime');
           return encodableMap;
        }).toList();

        String appointmentsJson = jsonEncode(encodableList);
        // Save using a user-specific key
        await prefs.setString(_prefsKeyAppointments + _loggedInUserId!, appointmentsJson);
        print("Appointments saved locally.");
     } catch (e) {
        print("Error saving appointments locally: $e");
     }
  }

  // Categorizes appointments from the main list into upcoming, past, and cancelled
  void _categorizeAppointments() {
    final now = DateTime.now();
    List<Map<String, dynamic>> upcoming = [];
    List<Map<String, dynamic>> past = [];
    List<Map<String, dynamic>> cancelled = [];

    for (var appointment in _appointments) {
      DateTime? appointmentDateTime = appointment['appointmentTime'] as DateTime?; // Already converted
      String status = (appointment['status'] ?? 'Unknown').toLowerCase();

      if (status == 'cancelled') {
        cancelled.add(appointment);
      } else if (appointmentDateTime != null && appointmentDateTime.isBefore(now)) {
        past.add(appointment);
      } else if (appointmentDateTime != null) { // Ensure it has a valid time to be upcoming
        upcoming.add(appointment);
      }
      // Appointments with invalid times might be ignored or put in a separate category if needed
    }

    // Sort categories (Upcoming: Oldest first; Past/Cancelled: Newest first)
    upcoming.sort((a, b) => (a['appointmentTime'] as DateTime).compareTo(b['appointmentTime'] as DateTime));
    past.sort((a, b) => (b['appointmentTime'] as DateTime).compareTo(a['appointmentTime'] as DateTime));
    cancelled.sort((a, b) => (b['appointmentTime'] as DateTime).compareTo(a['appointmentTime'] as DateTime));

    // Update state to reflect categorization
    if (mounted) {
      setState(() {
        _upcomingAppointments = upcoming;
        _pastAppointments = past;
        _cancelledAppointments = cancelled;
      });
    }
  }

  // Handles the cancellation process for an appointment
  Future<void> _handleCancelAppointment(Map<String, dynamic> appointment) async {
    final String? appointmentId = appointment['id'];
    // Prevent action if ID is missing, not mounted, or already cancelling
    if (appointmentId == null || !mounted || _cancellingAppointmentIds.contains(appointmentId)) {
      return;
    }

    // Show Confirmation Dialog
    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Appointment?'),
          content: const Text('Are you sure you want to cancel this appointment?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false), // Return false
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
              onPressed: () => Navigator.of(context).pop(true), // Return true
            ),
          ],
        );
      },
    );

    // Proceed only if user confirmed
    if (confirmCancel == true) {
      if (!mounted) return;
      setState(() {
        _cancellingAppointmentIds.add(appointmentId); // Mark as cancelling
      });

      try {
        // Update the status in Firestore
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({'status': 'Cancelled'});

        // Update local state immediately for responsiveness
        if (mounted) {
          setState(() {
            // Find the appointment in the main list and update its status
            int index = _appointments.indexWhere((appt) => appt['id'] == appointmentId);
            if (index != -1) {
               _appointments[index]['status'] = 'Cancelled';
               // Re-run categorization to move the appointment visually
               _categorizeAppointments();
            }
          });
          // Update the local cache with the modified full list
          await _saveAppointmentsLocally(_appointments);

          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully.'),
              backgroundColor: Colors.orange, // Use a distinct color for cancellation
            ),
          );
        }
      } catch (e) {
        print("Error cancelling appointment: $e");
        if (mounted) {
          // Show error feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel appointment: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Always remove from the cancelling set, regardless of outcome
        if (mounted) {
          setState(() {
            _cancellingAppointmentIds.remove(appointmentId);
          });
        }
      }
    }
  }

  // Builds the main UI for the screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed - Title is now handled by Home.dart
      body: _buildAppointmentList(),
    );
  }

  // Builds the list view containing sections or status messages
  Widget _buildAppointmentList() {
    if (_isLoading && _upcomingAppointments.isEmpty && _pastAppointments.isEmpty && _cancelledAppointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Show error ONLY if all lists are empty
    if (_error != null && _upcomingAppointments.isEmpty && _pastAppointments.isEmpty && _cancelledAppointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
               const SizedBox(height: 10),
               ElevatedButton.icon(
                 icon: const Icon(Icons.refresh),
                 label: const Text('Retry'),
                 onPressed: _loadAppointmentsFromFirestore, // Allow retry
               )
             ],
           ),
        ),
      );
    }
    // Show empty message if not loading, no error, and all lists are empty
    if (!_isLoading && _error == null && _upcomingAppointments.isEmpty && _pastAppointments.isEmpty && _cancelledAppointments.isEmpty) {
      return RefreshIndicator(
         onRefresh: _loadAppointmentsFromFirestore, // Allow refresh even when empty
         child: LayoutBuilder( // Use LayoutBuilder to make message scrollable
           builder: (context, constraints) => SingleChildScrollView(
             physics: const AlwaysScrollableScrollPhysics(), // Ensure scrollability
             child: ConstrainedBox(
               constraints: BoxConstraints(minHeight: constraints.maxHeight), // Take full height
               child: const Center(child: Text('No appointments found.')), // General empty message
             ),
           ),
         ),
       );
    }

    // Build the list using sections if there's data
    return RefreshIndicator(
      onRefresh: _loadAppointmentsFromFirestore, // Enable pull-to-refresh
      child: ListView( // Use a simple ListView for sections
        children: [
          // --- Upcoming Section ---
          if (_upcomingAppointments.isNotEmpty) ...[
            _buildSectionHeader('Upcoming Appointments'),
            // Map upcoming appointments to cards
            ..._upcomingAppointments.map((appt) => _buildAppointmentCard(appt, isPastOrCancelled: false)),
          ],

          // --- Past Section ---
          if (_pastAppointments.isNotEmpty) ...[
            _buildSectionHeader('Past Appointments'),
            // Map past appointments to cards (styled differently)
            ..._pastAppointments.map((appt) => _buildAppointmentCard(appt, isPastOrCancelled: true)),
          ],

          // --- Cancelled Section ---
          if (_cancelledAppointments.isNotEmpty) ...[
            _buildSectionHeader('Cancelled Appointments'),
            // Map cancelled appointments to cards (styled differently)
            ..._cancelledAppointments.map((appt) => _buildAppointmentCard(appt, isPastOrCancelled: true)),
          ],

           // Add some padding at the bottom
           const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Helper widget for section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  // Builds a card widget for a single appointment
  Widget _buildAppointmentCard(Map<String, dynamic> appointment, {required bool isPastOrCancelled}) {
    // Extract data safely
    String doctorName = appointment['doctorName'] ?? 'N/A';
    String specialty = appointment['doctorSpecialty'] ?? 'N/A';
    String status = appointment['status'] ?? 'Unknown';
    String imageUrl = appointment['doctorImageUrl'] ?? '';
    String? appointmentId = appointment['id'];
    bool isCurrentlyCancelling = _cancellingAppointmentIds.contains(appointmentId);

    // Format date and time
    String dateStr = 'N/A';
    String timeStr = 'N/A';
    DateTime? appointmentDateTime = appointment['appointmentTime'] as DateTime?; // Should be DateTime now

    if (appointmentDateTime != null) {
      dateStr = DateFormat.yMMMd().format(appointmentDateTime); // e.g., Apr 23, 2025
      timeStr = DateFormat.jm().format(appointmentDateTime); // e.g., 10:30 AM
    }

    // Determine if cancellation is allowed
    bool canCancel = status.toLowerCase() == 'scheduled' &&
                     appointmentDateTime != null &&
                     appointmentDateTime.isAfter(DateTime.now());

    // Apply visual styling for past/cancelled appointments
    double cardOpacity = isPastOrCancelled ? 0.65 : 1.0;
    Color? titleColor = isPastOrCancelled ? Colors.grey.shade600 : null;
    Color? subtitleColor = isPastOrCancelled ? Colors.grey.shade500 : Colors.grey.shade700;
    Color? dateTimeColor = isPastOrCancelled ? Colors.grey.shade500 : Colors.grey.shade600;

    return Opacity(
      opacity: cardOpacity,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: isPastOrCancelled ? 1 : 2, // Slightly less elevation
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
                  imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/60?text=N/A',
                  width: 60, height: 60, fit: BoxFit.cover,
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
                    Text(doctorName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleColor)),
                    const SizedBox(height: 4),
                    Text(specialty, style: TextStyle(fontSize: 14, color: subtitleColor)),
                    const SizedBox(height: 8),
                    Row( // Date and Time
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: dateTimeColor),
                        const SizedBox(width: 4),
                        Text(dateStr, style: TextStyle(fontSize: 14, color: dateTimeColor)),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_outlined, size: 14, color: dateTimeColor),
                        const SizedBox(width: 4),
                        Text(timeStr, style: TextStyle(fontSize: 14, color: dateTimeColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Status Badge and Cancel Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusBadge(status), // Status badge
                        // Show Cancel Button or Loading Indicator conditionally
                        if (canCancel)
                          isCurrentlyCancelling
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _handleCancelAppointment(appointment),
                                child: const Text('Cancel'),
                              )
                        // Add a placeholder if not cancellable but need to maintain spacing, unless cancelled
                        else if (status.toLowerCase() != 'cancelled')
                           const SizedBox(height: 24), // Placeholder with height
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to build a status badge
  Widget _buildStatusBadge(String status) {
     Color badgeColor;
     String displayStatus = status; // Use original case for display

    switch (status.toLowerCase()) {
      case 'scheduled': badgeColor = Colors.blue; break;
      case 'completed': badgeColor = Colors.green; break;
      case 'pending': badgeColor = Colors.orange; break;
      case 'cancelled': badgeColor = Colors.red; break;
      default: badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayStatus, // Display original status text
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

} // End of _AppointmentsState
