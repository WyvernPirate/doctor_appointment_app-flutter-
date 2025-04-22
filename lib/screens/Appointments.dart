// lib/screens/Appointments.dart
import 'dart:convert';
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
      await _loadLocalAppointments();
      await _loadAppointmentsFromFirestore();
    } else {
      if (mounted) {
         setState(() {
           _error = "Please log in to view appointments.";
           _isLoading = false;
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
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? appointmentsJson = prefs.getString(_prefsKeyAppointments + _loggedInUserId!);

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(appointmentsJson);
        final List<Map<String, dynamic>> localAppointments = decodedList.map((item) {
          if (item is Map) {
             Map<String, dynamic> appointmentMap = Map<String, dynamic>.from(item);
             if (appointmentMap['appointmentTimeMillis'] is int) {
                appointmentMap['appointmentTime'] = DateTime.fromMillisecondsSinceEpoch(appointmentMap['appointmentTimeMillis']);
             }
             return appointmentMap;
          }
          return <String, dynamic>{};
        }).where((map) => map.isNotEmpty).toList();

        if (mounted) {
          setState(() {
            _appointments = localAppointments;
            _error = null;
          });
        }
      }
    } catch (e) {
      print("Error loading local appointments: $e");
    }
  }

  Future<void> _loadAppointmentsFromFirestore() async {
    if (!mounted || _loggedInUserId == null) return;
    if (!_isLoading) {
       setState(() { _isLoading = true; });
    }
    setState(() { _error = null; });

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: _loggedInUserId)
          // Filter out cancelled appointments from the main view
          .where('status', isNotEqualTo: 'Cancelled')
          .orderBy('status') 
          .orderBy('appointmentTime', descending: false)
          .get();

      if (mounted) {
        final List<Map<String, dynamic>> firestoreAppointments = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          if (data['appointmentTime'] is Timestamp) {
             data['appointmentTime'] = (data['appointmentTime'] as Timestamp).toDate();
          }
          return data;
        }).toList();

        setState(() {
          _appointments = firestoreAppointments;
          _isLoading = false;
          _error = null;
        });

        // --- Save fetched data locally ---
        await _saveAppointmentsLocally(firestoreAppointments);
      }
    } catch (e) {
      print("Error fetching appointments from Firestore: $e");
      if (mounted) {
        if (_appointments.isEmpty) {
          setState(() {
            _error = "Failed to load appointments.";
            _isLoading = false;
          });
        } else {
          setState(() { _isLoading = false; });
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
        List<Map<String, dynamic>> encodableList = appointments.map((appointment) {
           Map<String, dynamic> encodableMap = Map.from(appointment);
           if (encodableMap['appointmentTime'] is DateTime) {
              encodableMap['appointmentTimeMillis'] = (encodableMap['appointmentTime'] as DateTime).millisecondsSinceEpoch;
           } else if (encodableMap['appointmentTime'] is Timestamp) {
              encodableMap['appointmentTimeMillis'] = (encodableMap['appointmentTime'] as Timestamp).millisecondsSinceEpoch;
           }
           encodableMap.remove('appointmentTime');
           return encodableMap;
        }).toList();
        String appointmentsJson = jsonEncode(encodableList);
        await prefs.setString(_prefsKeyAppointments + _loggedInUserId!, appointmentsJson);
        print("Appointments saved locally.");
     } catch (e) {
        print("Error saving appointments locally: $e");
     }
  }

  // --- Handle Appointment Cancellation ---
  Future<void> _handleCancelAppointment(Map<String, dynamic> appointment) async {
    final String? appointmentId = appointment['id'];
    if (appointmentId == null || !mounted || _cancellingAppointmentIds.contains(appointmentId)) {
      return; // Prevent double cancellation or if ID is missing
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
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // Proceed if user confirmed
    if (confirmCancel == true) {
      if (!mounted) return;
      setState(() {
        _cancellingAppointmentIds.add(appointmentId); 
      });

      try {
        // Update Firestore status
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({'status': 'Cancelled'});

        // Update local state and cache
        if (mounted) {
          setState(() {
            // Remove the appointment from the local list
            _appointments.removeWhere((appt) => appt['id'] == appointmentId);
          });
          // Update the local cache without the cancelled appointment
          await _saveAppointmentsLocally(_appointments);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print("Error cancelling appointment: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel appointment: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _cancellingAppointmentIds.remove(appointmentId);
          });
        }
      }
    }
  }

  // Helper function to build an appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    String doctorName = appointment['doctorName'] ?? 'N/A';
    String specialty = appointment['doctorSpecialty'] ?? 'N/A';
    String status = appointment['status'] ?? 'Unknown';
    String imageUrl = appointment['doctorImageUrl'] ?? '';
    String? appointmentId = appointment['id']; // Get the ID
    bool isCurrentlyCancelling = _cancellingAppointmentIds.contains(appointmentId); 

    String dateStr = 'N/A';
    String timeStr = 'N/A';
    DateTime? appointmentDateTime; 

    if (appointment['appointmentTime'] is DateTime) {
      appointmentDateTime = appointment['appointmentTime'] as DateTime;
      dateStr = DateFormat.yMMMd().format(appointmentDateTime);
      timeStr = DateFormat.jm().format(appointmentDateTime);
    } else if (appointment['appointmentTimeMillis'] is int) {
       appointmentDateTime = DateTime.fromMillisecondsSinceEpoch(appointment['appointmentTimeMillis']);
       dateStr = DateFormat.yMMMd().format(appointmentDateTime);
       timeStr = DateFormat.jm().format(appointmentDateTime);
    }

    // Determine if cancellation should be possible
    bool canCancel = status.toLowerCase() == 'scheduled' &&
                     appointmentDateTime != null &&
                     appointmentDateTime.isAfter(DateTime.now()); // Can only cancel future scheduled appointments

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
                  Row( 
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(dateStr, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(timeStr, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ], ),
                  const SizedBox(height: 10),
                  // Status Badge and Cancel Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      _buildStatusBadge(status), 
                      // Show Cancel Button conditionally
                      if (canCancel)
                        isCurrentlyCancelling
                          ? const SizedBox( 
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5)
                            )
                          : TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                padding: EdgeInsets.zero, 
                                visualDensity: VisualDensity.compact, 
                              ),
                              onPressed: () => _handleCancelAppointment(appointment), 
                              child: const Text('Cancel'),
                            ),
                    ],
                  ),
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
     if (_isLoading && _appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _appointments.isEmpty) {
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
                 onPressed: _loadAppointmentsFromFirestore, 
               )
             ],
           ),
        ),
      );
    }
    if (!_isLoading && _error == null && _appointments.isEmpty) {
      return RefreshIndicator( // Allow refresh even when empty
         onRefresh: _loadAppointmentsFromFirestore,
         child: LayoutBuilder(
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
    return RefreshIndicator(
      onRefresh: _loadAppointmentsFromFirestore,
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
     Color badgeColor;
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
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12, 
        ),
      ),
    );
  }
}
