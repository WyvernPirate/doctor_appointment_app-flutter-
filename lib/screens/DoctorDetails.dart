// lib/screens/DoctorDetails.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/doctor.dart'; // Ensure this path is correct
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // --- Map Controller ---

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Combined initialization
  Future<void> _initialize() async {
    await _loadUserId();
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
  // REMOVED the incorrect first _handleBooking function
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
        );
      },
    );
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLoading || _doctor == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _handleBooking,
              label: const Text('Book Appointment'),
              icon: const Icon(Icons.calendar_today_outlined),
              backgroundColor: Theme.of(context).primaryColor,
              // foregroundColor: Colors.white, // REMOVED: Not a direct property
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
      bottom: true,
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
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
              },
            ),
          ),
        ),
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
                  
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
              onTap: () => _launchMap(doctor.location, doctor.address),
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
            // CORRECTED: Working Hours ListTile with null/empty check
            ListTile(
               leading: Icon(Icons.access_time_outlined, color: Theme.of(context).primaryColor),
               title: const Text('Working Hours'),
              /// subtitle: Text(
                // (doctor.workingHours != null && doctor.workingHours!.isNotEmpty)
                 //  ? doctor.workingHours!
                 //  : 'Not Available'
             //  ),
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

} 

class _BookingBottomSheetContent extends StatefulWidget {
  final Doctor doctor;
  final String userId;

  const _BookingBottomSheetContent({
    required this.doctor,
    required this.userId,
  });

  @override
  State<_BookingBottomSheetContent> createState() => _BookingBottomSheetContentState();
}

class _BookingBottomSheetContentState extends State<_BookingBottomSheetContent> {
  DateTime? _selectedDate;
  DateTime? _selectedTime;
  bool _isBooking = false;

  @override
  void initState() {
     super.initState();
    final now = DateTime.now();
    final DateTime firstValidDate = (now.hour >= 16)
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day);
    _selectedDate = firstValidDate;
    _selectedTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 9, 0,
    );
  }

  DateTime? get _finalSelectedDateTime {
     if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );
  }

  Future<void> _confirmBooking() async {
    final bookingDateTime = _finalSelectedDateTime;
    if (bookingDateTime == null || _isBooking) {
      return;
    }

    if (!mounted) return;
    setState(() { _isBooking = true; });

    final appointmentData = {
      'doctorId': widget.doctor.id,
      'doctorName': widget.doctor.name,
      'doctorSpecialty': widget.doctor.specialty,
      'doctorImageUrl': widget.doctor.imageUrl,
      'userId': widget.userId,
      'appointmentTime': Timestamp.fromDate(bookingDateTime),
      'status': 'Scheduled',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('appointments').add(appointmentData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking confirmed for ${widget.doctor.name}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error booking appointment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book appointment: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isBooking = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
     final now = DateTime.now();
    final DateTime firstBookableDate = (now.hour >= 16) ? DateTime(now.year, now.month, now.day + 1) : DateTime(now.year, now.month, now.day);
    final DateTime lastBookableDate = now.add(const Duration(days: 90));
   final DateTime minTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 9, 0); 
    final DateTime maxTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 16, 0); 
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0, right: 16.0, top: 20.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.0
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                if (!newDate.isBefore(firstBookableDate)) {
                  setState(() {
                    _selectedDate = newDate;
          
                    DateTime potentialNewTime = DateTime(
                      newDate.year, newDate.month, newDate.day,
                      _selectedTime?.hour ?? 9, 
                      _selectedTime?.minute ?? 0 
                    );
                   
                    if (potentialNewTime.isBefore(minTime)) {
                       potentialNewTime = minTime;
                    } else if (potentialNewTime.isAfter(maxTime)) {
                       potentialNewTime = DateTime(newDate.year, newDate.month, newDate.day, 9, 0);
                    }
                    _selectedTime = potentialNewTime;
                 } ); 
                }
              },
            ),
            const Divider(height: 20),

            // Time Picker
            Text('Time (9:00 AM - 4:00 PM)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: _selectedTime ?? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 9, 0),
                  minimumDate: minTime,
                  maximumDate: maxTime,
                  minuteInterval: 15,
                  use24hFormat: false,
                  onDateTimeChanged: (newTime) {
                    setState(() {
                       _selectedTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, newTime.hour, newTime.minute);
                    });
                  },
                ),
              ),
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
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: (_selectedDate != null && _selectedTime != null && !_isBooking) ? _confirmBooking : null,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
