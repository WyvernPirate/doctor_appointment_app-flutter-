// lib/screens/DoctorDetails.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // If showing map
import 'package:url_launcher/url_launcher.dart'; // For launching calls/maps
import '/models/doctor.dart';
import 'package:flutter/cupertino.dart';

// --- Main Details Screen Widget ---
class DoctorDetails extends StatefulWidget {
  final String doctorId; // ID of the doctor to display

  const DoctorDetails({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorDetails> createState() => _DoctorDetailsState();
}

class _DoctorDetailsState extends State<DoctorDetails> {
  Doctor? _doctor; // Holds the fetched doctor data
  bool _isLoading = true;
  String? _error;

  // --- Map Controller (Optional) ---
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails();
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
      if (!mounted) return; // Check mounted before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available.')),
      );
      return;
    }
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
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
  Future<void> _launchMap(LatLng? location, String? address) async {
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
    } else {
      query = Uri.encodeComponent(address!);
    }

    // Universal Maps URL works across platforms
    final Uri mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    // Platform specific URLs (optional, might give better integration)
    final Uri appleMapUri = Uri.parse('maps://?q=$query');
    final Uri googleMapUri = Uri.parse('geo:$query');

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

  // --- Handle Booking Action: Show Bottom Sheet ---
  void _handleBooking() {
    if (_doctor == null) return; // Don't show if doctor data isn't loaded

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to take more height if needed
      shape: const RoundedRectangleBorder( // Optional: Rounded top corners
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        // Return the stateful widget that contains the sheet content
        return _BookingBottomSheetContent(doctor: _doctor!);
      },
    );
  }


  // --- Build Method for the Screen ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading || _doctor == null ? 'Details' : _doctor!.name),
        elevation: 1,
        actions: [
          // Optional: Favorite toggle button
          if (_doctor != null)
            IconButton(
              icon: Icon(
                _doctor!.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _doctor!.isFavorite ? Colors.redAccent : null,
              ),
              tooltip: _doctor!.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              onPressed: () {
                // TODO: Implement favorite toggle logic (update Firestore & local state)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Favorite toggle for ${_doctor!.name} (Not implemented)'))
                );
              },
            )
        ],
      ),
      body: _buildBodyContent(),

      // --- Floating Action Button for Booking ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Position
      floatingActionButton: _isLoading || _doctor == null // Show only when loaded
          ? null // Hide if loading or error
          : FloatingActionButton.extended( // Use the correct widget name
              onPressed: _handleBooking, // Trigger the bottom sheet
              label: const Text('Book Appointment'),
              icon: const Icon(Icons.calendar_today_outlined),
              backgroundColor: Theme.of(context).primaryColor, // Use theme color
              // foregroundColor: Colors.white, // Handled by theme usually
            ),
    );
  }

  // --- Body Content Builder ---
  Widget _buildBodyContent() {
    // Handle Loading State
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

    // --- Build UI when Doctor Data is Loaded ---
    final doctor = _doctor!;
    return SafeArea( // Ensure content avoids notches and system areas
      bottom: true, // Apply safe area to bottom for FAB
      top: false, // AppBar handles top safe area
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90), // Padding below content for FAB
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
            // Optional Map Section
            if (doctor.location != null)
              _buildMapSection(doctor),
            // Optional About Section
            // Check if 'bio' field exists in your Doctor model and Firestore
            if (doctor.bio != null && doctor.bio!.isNotEmpty)
               _buildAboutSection(doctor),
          ],
        ),
      ),
    );
  }

  // --- Header Section ---
  Widget _buildHeaderSection(Doctor doctor) {
    return Stack(
      clipBehavior: Clip.none, // Allow avatar to overflow
      alignment: Alignment.topCenter,
      children: [
        // Background color area
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
              },
            ),
          ),
        ),
        // Text content positioned below the avatar area
        Padding(
          padding: const EdgeInsets.only(top: 240.0),
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
                    '${doctor.rating.toStringAsFixed(1)} ',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Info Section (Address, Phone, Working Hours) ---
  Widget _buildInfoSection(Doctor doctor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            // Address ListTile
            ListTile(
              leading: Icon(Icons.location_on_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Address'),
              subtitle: Text(doctor.address.isNotEmpty ? doctor.address : 'Not Available'),
              trailing: const Icon(Icons.launch, size: 18, color: Colors.blue), // Indicate tappable
              onTap: () => _launchMap(doctor.location, doctor.address), // Launch maps app
              dense: true,
            ),
            _buildDivider(),
            ListTile(
              leading: Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Phone'),
              subtitle: Text(doctor.phone.isNotEmpty ? doctor.phone : 'Not Available'),
              trailing: const Icon(Icons.launch, size: 18, color: Colors.blue), // Indicate tappable
              onTap: () => _launchCaller(doctor.phone), // Launch phone dialer
              dense: true,
            ),
            _buildDivider(), // Separator line
            // Working Hours ListTile (Check if data exists)
            ListTile(
               leading: Icon(Icons.access_time_outlined, color: Theme.of(context).primaryColor),
               title: const Text('Working Hours'),
              // subtitle: Text(
                 // Check if 'workingHours' field exists in your Doctor model and has data
                // (doctor.workingHours != null && doctor.workingHours!.isNotEmpty)
                 //  ? doctor.workingHours!
                  // : 'Not Available'
              // ),
               dense: true,
             ),
          ],
        ),
      ),
    );
  }

  // --- About Section (Optional) ---
  Widget _buildAboutSection(Doctor doctor) {
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
             doctor.bio!, // Display the bio text
             style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.grey.shade800),
           ),
         ],
       ),
     );
  }

  // --- Map Section (Optional) ---
  Widget _buildMapSection(Doctor doctor) {
    // Show map only if location data is available
    if (doctor.location == null) return const SizedBox.shrink();

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect( 
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: doctor.location!,
            zoom: 15.0,
          ),
          markers: {
            Marker(
              markerId: MarkerId(doctor.id),
              position: doctor.location!,
              infoWindow: InfoWindow(title: doctor.name, snippet: doctor.address),
            ),
          },
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
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

} // End of _DoctorDetailsState

// --- Booking Bottom Sheet Content Widget ---
// (Place this within the same DoctorDetails.dart file, but outside the _DoctorDetailsState class)
class _BookingBottomSheetContent extends StatefulWidget {
  final Doctor doctor; // Pass doctor info if needed for booking logic

  const _BookingBottomSheetContent({required this.doctor});

  @override
  State<_BookingBottomSheetContent> createState() => _BookingBottomSheetContentState();
}

class _BookingBottomSheetContentState extends State<_BookingBottomSheetContent> {
  DateTime? _selectedDate;
  DateTime? _selectedTime; // Using DateTime to easily combine later

  @override
  void initState() {
    super.initState();
    // Initialize with today's date and a default time (e.g., 9:00 AM)
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = DateTime(
      now.year,
      now.month,
      now.day,
      9, // Default hour (9 AM)
      0, // Default minute (00)
    );
  }

  // Helper to combine selected date and time into a single DateTime object
  DateTime? get _finalSelectedDateTime {
    if (_selectedDate == null || _selectedTime == null) {
      return null; // Return null if either date or time is not selected
    }
    // Combine date part from _selectedDate and time part from _selectedTime
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  // --- Placeholder for Actual Booking Logic ---
  Future<void> _confirmBooking() async {
    final bookingDateTime = _finalSelectedDateTime;
    if (bookingDateTime == null) {
      // Should not happen if button is enabled correctly, but good practice
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time.')),
      );
      return;
    }

    // Close the bottom sheet first
    if (mounted) {
       Navigator.pop(context); // Close the sheet
    }

    // TODO: Implement Actual Booking Logic Here
    
        // Show success message
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(
               'Booking confirmed for ${widget.doctor.name} on ${bookingDateTime.toLocal().toString().substring(0, 16)}',
             ),
             duration: const Duration(seconds: 4),
           ),
         );

    // } catch (e) {
    //   // Dismiss loading indicator
    //   // dismissLoadingDialog();
    //   // Show error message
    //   showErrorSnackBar("Failed to book appointment: $e");
    // }
    // --- End of TODO ---
  }


  @override
  Widget build(BuildContext context) {
    // Define date/time constraints
    final now = DateTime.now();
    // Set first bookable date (e.g., today or tomorrow)
    final DateTime firstBookableDate = (now.hour >= 16) ? DateTime(now.year, now.month, now.day + 1) : DateTime(now.year, now.month, now.day);
    // Set last bookable date (e.g., 90 days from now)
    final DateTime lastBookableDate = now.add(const Duration(days: 90));
    // Define time boundaries for the picker (e.g., 9:00 AM to 4:00 PM)
    final DateTime minTime = DateTime(now.year, now.month, now.day, 9, 0);
    final DateTime maxTime = DateTime(now.year, now.month, now.day, 16, 0);

    return SingleChildScrollView( // Ensures content scrolls if screen is small
      child: Padding(
        // Add padding around the content and for the bottom safe area
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 20.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.0 // Adjust for keyboard if needed
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Sheet height adjusts to content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header with Title and Close Button ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Date & Time',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context), // Dismiss the sheet
                )
              ],
            ),
            const Divider(height: 20),

            // --- Date Picker Section ---
            Text('Date', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            CalendarDatePicker(
              initialDate: (_selectedDate != null && _selectedDate!.isAfter(firstBookableDate.subtract(const Duration(days:1))))
                           ? _selectedDate!
                           : firstBookableDate, // Ensure initial date is valid
              firstDate: firstBookableDate, // Cannot book in the past or too early today
              lastDate: lastBookableDate, // Furthest booking date
              onDateChanged: (newDate) {
                setState(() {
                  _selectedDate = newDate;
                  // Update _selectedTime to keep the same time but on the new date
                  // This ensures the time picker doesn't reset unexpectedly
                  if (_selectedTime != null) {
                     _selectedTime = DateTime(
                       newDate.year,
                       newDate.month,
                       newDate.day,
                       _selectedTime!.hour,
                       _selectedTime!.minute,
                     );
                  }
                });
              },
            ),
            const Divider(height: 20),

            // --- Time Picker Section ---
            Text('Time (9:00 AM - 4:00 PM)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 150, // Provide adequate height for the picker
              child: CupertinoTheme( // Optional: Use Material theme styles if preferred
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    // Style the text within the picker
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).textTheme.bodyLarge?.color, // Match app theme
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time, // Show only time picker
                  initialDateTime: _selectedTime, // Start at the selected/default time
                  minimumDate: minTime, // Earliest selectable time (9:00 AM)
                  maximumDate: maxTime, // Latest selectable time (4:00 PM)
                  minuteInterval: 30, // Allow selection in 30-minute increments
                  use24hFormat: false, // Use AM/PM format
                  onDateTimeChanged: (newTime) {
                    // Update the time state, keeping the selected date
                    setState(() {
                       _selectedTime = DateTime(
                         _selectedDate!.year, // Keep year from selected date
                         _selectedDate!.month, // Keep month from selected date
                         _selectedDate!.day, // Keep day from selected date
                         newTime.hour, // Update hour from picker
                         newTime.minute, // Update minute from picker
                       );
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- Confirmation Button ---
            Center( // Center the button horizontally
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm Booking'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                // Button is enabled only if both date and time are selected
                onPressed: (_selectedDate != null && _selectedTime != null)
                    ? _confirmBooking // Call booking logic
                    : null, // Disable button otherwise
              ),
            ),
            const SizedBox(height: 10), // Extra space at the bottom
          ],
        ),
      ),
    );
  }
}
