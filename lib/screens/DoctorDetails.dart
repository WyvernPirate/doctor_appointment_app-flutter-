// lib/screens/DoctorDetails.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // If showing map
import 'package:url_launcher/url_launcher.dart'; // For launching calls/maps
import '/models/doctor.dart';

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

  // --- Map Controller ---
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone dialer for $phoneNumber')),
      );
    }
  }

  // --- Helper to launch maps ---
  Future<void> _launchMap(LatLng? location, String? address) async {
    if (location == null && (address == null || address.isEmpty)) {
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

    // Universal Maps URL
    final Uri mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    // Platform specific URLs (optional, might give better integration)
    final Uri appleMapUri = Uri.parse('maps://?q=$query');
    final Uri googleMapUri = Uri.parse('geo:$query');

    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
       print('Could not launch $mapUri');
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps application.')),
      );
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
          // Optional: Add favorite toggle button here if needed
          if (_doctor != null)
            IconButton(
              icon: Icon(
                _doctor!.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _doctor!.isFavorite ? Colors.redAccent : null,
              ),
              tooltip: _doctor!.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              onPressed: () {
                // TODO: Implement favorite toggle logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Favorite toggle for ${_doctor!.name} (Not implemented)'))
                );
              },
            )
        ],
      ),
      body: _buildBodyContent(),
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
      // This case should ideally be covered by _error, but acts as a fallback
      return const Center(child: Text("Doctor data is unavailable."));
    }

    // Doctor data is loaded, build the details UI
    final doctor = _doctor!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80), // Padding for the floating button
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
           if (doctor.location != null)
             _buildMapSection(doctor),
          // Optional About Section
          if (doctor.bio.isNotEmpty) // Assuming a 'bio' field exists
             _buildAboutSection(doctor),

        ],
      ),
    );
  }

  // --- Header Section ---
  Widget _buildHeaderSection(Doctor doctor) {
    return Stack(
      clipBehavior: Clip.none, // Allow avatar to overflow slightly
      alignment: Alignment.topCenter,
      children: [
        // Background (optional, could be a color or blurred image)
        Container(
          height: 150,
          width: double.infinity,
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          // Or use doctor.imageUrl here for a background effect
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
                  : const AssetImage('assets/profile_placeholder.png') as ImageProvider, // Placeholder
              onBackgroundImageError: (exception, stackTrace) {
                 print("Error loading doctor image: $exception");
              },
            ),
          ),
        ),
        // Text content below the image area
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
              trailing: const Icon(Icons.launch, size: 18, color: Colors.blue), // Indicate tappable
              onTap: () => _launchMap(doctor.location, doctor.address), // Launch map
              dense: true,
            ),
            _buildDivider(),
            ListTile(
              leading: Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Phone'),
              subtitle: Text(doctor.phone.isNotEmpty ? doctor.phone : 'Not Available'),
              trailing: const Icon(Icons.launch, size: 18, color: Colors.blue), // Indicate tappable
              onTap: () => _launchCaller(doctor.phone), // Launch dialer
              dense: true,
            ),
            // Add more details if available (e.g., working hours)
            _buildDivider(),
            ListTile(
               leading: Icon(Icons.access_time_outlined, color: Theme.of(context).primaryColor),
               title: const Text('Working Hours'),
              // subtitle: Text(doctor.workingHours ?? 'Not Available'), // Assuming workingHours field
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
             doctor.bio!, // Assuming 'bio' field exists and is not null
             style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.grey.shade800),
           ),
         ],
       ),
     );
  }

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
            _mapController = controller;
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
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

  // --- Floating Action Button (Placeholder) ---
  // Consider adding a FloatingActionButton for booking if needed
} 
