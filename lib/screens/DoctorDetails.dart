// lib/screens/DoctorDetails.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/doctor.dart'; // Ensure this path is correct
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date/time formatting

// --- Main Details Screen Widget ---
class DoctorDetails extends StatefulWidget {
  final String doctorId;

  const DoctorDetails({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorDetails> createState() => _DoctorDetailsState();
}

class _DoctorDetailsState extends State<DoctorDetails> {
  Doctor? _doctor;
  bool _isLoading = true;
  String? _error;
  String? _loggedInUserId;
  Set<String> _userFavoriteIds = {}; // State to hold user's favorite doctor IDs
  final Set<String> _togglingFavorite = {}; // State to prevent rapid toggles

  // --- Map Controller ---

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Combined initialization
  Future<void> _initialize() async {
    await _loadUserId();
    await _loadUserFavorites(); // Load favorites after getting user ID
    await _fetchDoctorDetails();
  }

  // Load logged-in user ID
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _loggedInUserId = prefs.getString('loggedInUserId');
      });
    }
  }

  // Load user's favorite doctor IDs
  Future<void> _loadUserFavorites() async {
    if (_loggedInUserId == null || !mounted) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_loggedInUserId!).get();
      if (userDoc.exists && userDoc.data() != null && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('favoriteDoctorIds') && data['favoriteDoctorIds'] is List) {
          setState(() {
            _userFavoriteIds = List<String>.from(data['favoriteDoctorIds']).toSet();
          });
        }
      }
    } catch (e) {
      print("Error loading user favorites in DoctorDetails: $e");
      // Optionally show a snackbar or handle error
    }
  }

  // Fetches doctor data from Firestore
  Future<void> _fetchDoctorDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _doctor = Doctor.fromFirestore(doc);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = "Doctor details not found.";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching doctor details: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load doctor details. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  // --- Helper to launch phone dialer ---
  Future<void> _launchCaller(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available.')),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print('Could not launch $launchUri');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone dialer for $phoneNumber')),
      );
    }
  }

  // --- Helper to launch maps ---
  Future<void> _launchMap(double? latitude, double? longitude, String? address) async {
    LatLng? location = (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0)
        ? LatLng(latitude, longitude)
        : null;

    if (location == null && (address == null || address.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location information not available.')),
      );
      return;
    }

    String query = '';
    if (location != null) {
      query = '${location.latitude},${location.longitude}';
    } else if (address != null && address.isNotEmpty) {
      query = Uri.encodeComponent(address);
    }

    final Uri mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $mapUri');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps application.')),
      );
    }
  }


  // --- CORRECT Handle Booking Action: Show Bottom Sheet ---
  void _handleBooking() {
    if (_doctor == null || _loggedInUserId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Cannot book appointment. User or doctor data missing.')),
       );
       return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return _BookingBottomSheetContent(
          doctor: _doctor!,
          userId: _loggedInUserId!,
          // Pass a callback to refresh doctor data after booking
          onBookingConfirmed: _fetchDoctorDetails,
        );
      },
    );
  }

  // --- Toggle Favorite Status ---
  Future<void> _toggleFavoriteStatus(String doctorId) async {
    if (_loggedInUserId == null || _togglingFavorite.contains(doctorId) || !mounted) return;

    final bool isCurrentlyFavorite = _userFavoriteIds.contains(doctorId);

    setState(() {
      _togglingFavorite.add(doctorId);
      // Optimistically update UI
      if (isCurrentlyFavorite) {
        _userFavoriteIds.remove(doctorId);
      } else {
        _userFavoriteIds.add(doctorId);
      }
    });

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(_loggedInUserId!);
    final updateData = isCurrentlyFavorite
        ? {'favoriteDoctorIds': FieldValue.arrayRemove([doctorId])}
        : {'favoriteDoctorIds': FieldValue.arrayUnion([doctorId])};

    try {
      await userDocRef.update(updateData);
      // Firestore update successful, UI is already updated optimistically
      if (mounted) {
        setState(() {
          _togglingFavorite.remove(doctorId);
        });
      }
    } catch (e) {
      print("Error toggling favorite in DoctorDetails: $e");
      // Rollback UI on error
      if (mounted) {
        setState(() {
          if (isCurrentlyFavorite) {
            // It failed to remove, so add it back to local state
            _userFavoriteIds.add(doctorId);
          } else {
            // It failed to add, so remove it from local state
            _userFavoriteIds.remove(doctorId);
          }
          _togglingFavorite.remove(doctorId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update favorites: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading || _doctor == null ? 'Details' : _doctor!.name),
        elevation: 1,
        actions: [
          // Favorite toggle button
          if (_doctor != null && _loggedInUserId != null && !_isLoading) // Only show if logged in and doctor loaded
            IconButton(
              // Check if the current doctor's ID is in the user's favorite set
              icon: Icon(
                _userFavoriteIds.contains(_doctor!.id) ? Icons.favorite : Icons.favorite_border,
                color: _userFavoriteIds.contains(_doctor!.id) ? Colors.redAccent : null,
              ),
              tooltip: _userFavoriteIds.contains(_doctor!.id) ? 'Remove from Favorites' : 'Add to Favorites',
              // Disable button while toggling
              onPressed: _togglingFavorite.contains(_doctor!.id)
                  ? null
                  : () {
                      _toggleFavoriteStatus(_doctor!.id);
              },
            )
        ],
      ),
      body: _buildBodyContent(),

      // --- Floating Action Button for Booking ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLoading || _doctor == null || _loggedInUserId == null // Disable if guest
          ? null
          : FloatingActionButton.extended(
              onPressed: _handleBooking,
              label: const Text('Book Appointment'),
              icon: const Icon(Icons.calendar_today_outlined),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white, // Added foregroundColor for better contrast
            ),
    );
  }

  // --- Body Content Builder ---
  Widget _buildBodyContent() {
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
    if (_doctor == null) {
      return const Center(child: Text("Doctor data is unavailable."));
    }

    final doctor = _doctor!;
    return SafeArea(
      bottom: true, // Ensure content avoids bottom system intrusions (like home bar)
      top: false, // AppBar handles top padding
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90), // Padding to avoid overlap with FAB
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(doctor),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildInfoSection(doctor),
            ),
            const SizedBox(height: 20),
            // Optional Map Section - Check if lat/long are valid (not the default 0.0)
            if (doctor.latitude != 0.0 || doctor.longitude != 0.0)
              _buildMapSection(doctor),
            // Optional About Section - Check for null/empty bio
            if (doctor.bio.isNotEmpty)
               _buildAboutSection(doctor),
          ],
        ),
      ),
    );
  }

  // --- Header Section ---
  Widget _buildHeaderSection(Doctor doctor) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: 150,
          width: double.infinity,
          color: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
        Positioned(
          top: 70,
          child: CircleAvatar(
            radius: 80,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 75,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: doctor.imageUrl.isNotEmpty
                  ? NetworkImage(doctor.imageUrl)
                  : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
              onBackgroundImageError: (exception, stackTrace) {
                 print("Error loading doctor image: $exception");
                 // Optionally set a flag to show a placeholder icon instead
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 240.0), // Adjust spacing below avatar
          child: Column(
            children: [
              Text(
                doctor.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                doctor.specialty,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 22),
                  const SizedBox(width: 5),
                  Text(
                    doctor.rating.toStringAsFixed(1), // Format rating
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  // You might want to add review count here if available
                  // Text(' (${doctor.reviewCount ?? 0} reviews)', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper to format working hours ---
  String _formatWorkingHours(Map<String, String> hours) {
    if (hours.isEmpty) {
      return 'Not Available';
    }
    // Example: Get today's hours or list all
    // For simplicity, let's list all for now
    return hours.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    // To get today's hours:
    // final today = DateFormat('EEEE').format(DateTime.now()); // e.g., 'Monday'
    // return hours[today] ?? 'Closed Today';
  }

  // --- Info Section ---
  Widget _buildInfoSection(Doctor doctor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.location_on_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Address'),
              subtitle: Text(doctor.address.isNotEmpty ? doctor.address : 'Not Available'),
              trailing: const Icon(Icons.launch, size: 18, color: Colors.blue),
              onTap: () => _launchMap(doctor.latitude, doctor.longitude, doctor.address),
              dense: true,
            ),
            _buildDivider(),
            ListTile(
              leading: Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Phone'),
              subtitle: Text(doctor.phone.isNotEmpty ? doctor.phone : 'Not Available'),
              trailing: const Icon(Icons.launch, size: 18, color: Colors.blue),
              onTap: () => _launchCaller(doctor.phone),
              dense: true,
            ),
            _buildDivider(),
            ListTile(
               leading: Icon(Icons.access_time_outlined, color: Theme.of(context).primaryColor),
               title: const Text('Working Hours'),
               subtitle: Text(
                 _formatWorkingHours(doctor.workingHours),
               ),
               dense: true,
             ),
          ],
        ),
      ),
    );
  }

  // --- About Section ---
  Widget _buildAboutSection(Doctor doctor) {
     // No need for '!' if called after the check in _buildBodyContent
     return Padding(
       padding: const EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'About ${doctor.name}',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
           ),
           const SizedBox(height: 8),
           Text(
             doctor.bio ,
             style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.grey.shade800),
           ),
         ],
       ),
     );
  }

  // --- Map Section ---
  Widget _buildMapSection(Doctor doctor) {
    // Already checked for 0.0 lat/long before calling this
    final LatLng position = LatLng(doctor.latitude, doctor.longitude);

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: Colors.grey.shade300), // Optional border
      ),
      child: ClipRRect( // Clip the map to the rounded corners
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: 15.0,
          ),
          markers: {
            Marker(
              markerId: MarkerId(doctor.id),
              position: position, // Use the LatLng position variable
              infoWindow: InfoWindow(title: doctor.name, snippet: doctor.address),
            ),
          },
          onMapCreated: (GoogleMapController controller) {
            // You can store the controller if needed: _mapController = controller;
          },
          zoomControlsEnabled: false, // Keep UI clean
          mapToolbarEnabled: false, // Disable default map toolbar
        ),
      ),
    );
  }

  // --- Reusable Divider Widget ---
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey.shade200,
    );
  }

}

// --- Booking Bottom Sheet Widget ---
class _BookingBottomSheetContent extends StatefulWidget {
  final Doctor doctor;
  final String userId;
  final VoidCallback onBookingConfirmed; // Callback to refresh parent

  const _BookingBottomSheetContent({
    required this.doctor,
    required this.userId,
    required this.onBookingConfirmed,
  });

  @override
  State<_BookingBottomSheetContent> createState() => _BookingBottomSheetContentState();
}

class _BookingBottomSheetContentState extends State<_BookingBottomSheetContent> {
  DateTime? _selectedDate;
  String? _selectedSlot; // Changed from DateTime? _selectedTime
  bool _isBooking = false;

  @override
  void initState() {
     super.initState();
    final now = DateTime.now();
    // Set initial date (today or tomorrow if it's late, e.g., after 5 PM)
    final DateTime firstValidDate = (now.hour >= 17) // Booking closes at 5 PM
        ? DateTime(now.year, now.month, now.day + 1, 0, 0) // Start from tomorrow midnight
        : DateTime(now.year, now.month, now.day, 0, 0); // Start from today midnight
    _selectedDate = firstValidDate;
    // Initial slot is not selected
    _selectedSlot = null;
  }


  Future<void> _confirmBooking() async {
    // --- Construct final DateTime from date and slot ---
    DateTime? bookingDateTime;
    if (_selectedDate != null && _selectedSlot != null) {
      try {
        // Assuming slots are like "HH:mm" (e.g., "09:30")
        final timeParts = _selectedSlot!.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        bookingDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, hour, minute);
      } catch (e) {
        print("Error parsing selected slot '$_selectedSlot': $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid time slot format: $_selectedSlot'), backgroundColor: Colors.red),
          );
        }
        return; // Stop booking if slot format is wrong
      }
    }

    if (bookingDateTime == null || _isBooking) {
      // Show message if date/slot not selected
      if (bookingDateTime == null && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please select a date and time slot.')),
         );
      }
      return;
    }

    if (!mounted) return;
    setState(() { _isBooking = true; });

    final appointmentData = {
      'doctorId': widget.doctor.id,
      'doctorName': widget.doctor.name,
      'doctorSpecialty': widget.doctor.specialty,
      'doctorImageUrl': widget.doctor.imageUrl, // Include image for appointment list display
      'userId': widget.userId,
      'appointmentTime': Timestamp.fromDate(bookingDateTime), // Use the combined DateTime
      'status': 'Scheduled', // Initial status
      'createdAt': FieldValue.serverTimestamp(), // Record creation time
    };

    // --- Pre-Transaction Check 1: Does user already have ANY appointment at this time? ---
    try {
      final existingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: widget.userId)
          .where('appointmentTime', isEqualTo: Timestamp.fromDate(bookingDateTime))
          .limit(1) // We only need to know if at least one exists
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You already have an appointment scheduled at this time.'), backgroundColor: Colors.orange),
        );
        setState(() { _isBooking = false; }); // Reset booking state
        return; // Stop the booking process
      }
    } catch (e) {
       print("Error checking existing user appointments: $e");
       // Optionally handle this error, maybe allow proceeding with caution or show specific error
    }

    // --- Use Firestore Transaction ---
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get a reference to the doctor's document
        DocumentReference doctorRef = FirebaseFirestore.instance.collection('doctors').doc(widget.doctor.id);

        // Get a reference for the new appointment document (Firestore generates ID)
        DocumentReference newAppointmentRef = FirebaseFirestore.instance.collection('appointments').doc();

        // --- Transaction Check 2: Read doctor's current data to ensure slot is still available ---
        DocumentSnapshot doctorSnapshot = await transaction.get(doctorRef);
        if (!doctorSnapshot.exists) {
          throw Exception("Doctor not found."); // Or handle differently
        }
        List<String> currentSlots = List<String>.from(doctorSnapshot.get('availableSlots') ?? []);

        if (!currentSlots.contains(_selectedSlot)) {
          // Slot is no longer available! Abort the transaction.
          throw FirebaseException(
              plugin: 'Firestore',
              code: 'unavailable-slot',
              message: 'Sorry, this time slot was just booked by someone else.');
        }

        // --- Slot is available, proceed with booking ---
        // 1. Create the new appointment
        transaction.set(newAppointmentRef, appointmentData);
        // 2. Remove the slot from the doctor's availability
        transaction.update(doctorRef, {'availableSlots': FieldValue.arrayRemove([_selectedSlot])});
      });

      // --- Transaction Successful ---
      if (mounted) {
        Navigator.pop(context); // Close the bottom sheet
        widget.onBookingConfirmed(); // Call the callback to refresh parent
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking confirmed for ${widget.doctor.name} on ${DateFormat.yMd().add_jm().format(bookingDateTime)}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) { // Catches errors from the transaction
      // --- Transaction Failed (or pre-check error) ---
      print("Error during booking transaction: $e");
      if (mounted) {
        String errorMessage = 'Failed to book appointment. Please try again.';
        // Check if it was our specific "unavailable-slot" error
        if (e is FirebaseException && e.code == 'unavailable-slot') {
          errorMessage = e.message ?? 'Sorry, this time slot is no longer available.';
        } else if (e.toString().contains("Doctor not found")) {
           errorMessage = 'Could not find doctor details to confirm booking.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // --- Always reset booking state ---
      if (mounted) {
        setState(() { _isBooking = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
     final now = DateTime.now();
    // Ensure first bookable date respects the logic from initState
    final DateTime firstBookableDate = (now.hour >= 17) ? DateTime(now.year, now.month, now.day + 1, 0, 0) : DateTime(now.year, now.month, now.day, 0, 0);
    final DateTime lastBookableDate = now.add(const Duration(days: 90)); // Allow booking up to 90 days in advance

    return SingleChildScrollView( // Makes content scrollable if it overflows
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0, right: 16.0, top: 20.0,
          // Adjust bottom padding to account for keyboard when/if needed
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.0
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take only needed vertical space
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Date & Time', style: Theme.of(context).textTheme.titleLarge),
                IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => Navigator.pop(context))
              ]
            ),
            const Divider(height: 20),

            // Date Picker
            Text('Date', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            CalendarDatePicker(
              initialDate: _selectedDate!,
              firstDate: firstBookableDate,
              lastDate: lastBookableDate,
              onDateChanged: (newDate) {
                // Basic validation (already handled by firstDate)
                // if (!newDate.isBefore(firstBookableDate)) {
                  setState(() {
                    // Reset selected slot when date changes
                    if (_selectedDate != newDate) {
                      _selectedSlot = null;
                    }
                    _selectedDate = newDate;
                  });
                // }
              },
            ),
            const Divider(height: 20),

            // --- Available Slots Selection ---
            Text('Available Slots', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Use the latest doctor data passed to the widget
            if (widget.doctor.availableSlots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Center(child: Text(
                  'No available slots found for this doctor on the selected date.', // Consider making this dynamic based on date
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                )),
              )
            else
              Wrap( // Use Wrap for flexible layout of chips
                spacing: 8.0, // Horizontal space between chips
                runSpacing: 8.0, // Vertical space between lines of chips
                children: widget.doctor.availableSlots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSlot = selected ? slot : null;
                      });
                    },
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder( // Softer corners
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                      )
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }).toList(), // Convert map result to a list of widgets
              ),
            const SizedBox(height: 25),

            // Confirmation Button
            Center(
              child: ElevatedButton.icon(
                icon: _isBooking
                    ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isBooking ? 'Booking...' : 'Confirm Booking'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Rounded button
                ),
                // Disable button if no slot selected or booking is in progress
                onPressed: (_selectedDate != null && _selectedSlot != null && !_isBooking) ? _confirmBooking : null,
              ),
            ),
            const SizedBox(height: 10), // Bottom padding inside the sheet
          ],
        ),
      ),
    );
  }
}
