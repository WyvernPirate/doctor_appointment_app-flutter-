// lib/widgets/home/home_map_view.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '/models/doctor.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching maps/navigation
import '/screens/DoctorDetails.dart'; // Import necessary screen

class HomeMapView extends StatefulWidget {
  final List<Doctor> doctors;
  final Position? currentUserPosition;
  final bool isLoadingLocation;
  final String? locationError;
  final VoidCallback onRetryLocation;
  final String? lightMapStyle; // Pass preloaded styles
  final String? darkMapStyle;  // Pass preloaded styles

  const HomeMapView({
    super.key,
    required this.doctors,
    required this.currentUserPosition,
    required this.isLoadingLocation,
    required this.locationError,
    required this.onRetryLocation,
    required this.lightMapStyle,
    required this.darkMapStyle,
  });

  @override
  State<HomeMapView> createState() => _HomeMapViewState();
}

class _HomeMapViewState extends State<HomeMapView> {
  GoogleMapController? _mapController;
  Brightness? _currentMapBrightness;
  Doctor? _selectedDoctor; // State to track the selected doctor for the custom info card

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Apply style when theme changes *after* map is created
    if (_mapController != null) {
      _applyMapStyleBasedOnTheme();
    }
  }

  @override
  void didUpdateWidget(covariant HomeMapView oldWidget) {
      super.didUpdateWidget(oldWidget);
      // If user position becomes available after map is created, move camera
      if (widget.currentUserPosition != null && oldWidget.currentUserPosition == null && _mapController != null) {
          print("Animating camera to user location after update.");
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(widget.currentUserPosition!.latitude, widget.currentUserPosition!.longitude),
              14.0,
            ),
          );
      }
  }


  Future<void> _applyMapStyleBasedOnTheme() async {
    if (_mapController == null || !mounted || (widget.lightMapStyle == null && widget.darkMapStyle == null)) {
      print("Map style application skipped: Controller null, not mounted, or styles not loaded.");
      return;
    }

    final currentThemeBrightness = Theme.of(context).brightness;
    // Avoid redundant style applications if brightness hasn't changed
    if (_currentMapBrightness == currentThemeBrightness) {
       print("Map style skipped: Brightness hasn't changed ($currentThemeBrightness).");
       return;
    }

    print("Attempting to apply map style for theme: $currentThemeBrightness");

    String? styleToApply;
    if (currentThemeBrightness == Brightness.dark && widget.darkMapStyle != null) {
      styleToApply = widget.darkMapStyle;
      print("Selected dark map style.");
    } else if (currentThemeBrightness == Brightness.light && widget.lightMapStyle != null) {
      styleToApply = widget.lightMapStyle;
      print("Selected light map style.");
    } else {
      // Fallback logic
       if (currentThemeBrightness == Brightness.dark && widget.lightMapStyle != null) {
        print("Warning: Dark map style missing, falling back to light style.");
        styleToApply = widget.lightMapStyle;
      } else if (currentThemeBrightness == Brightness.light && widget.darkMapStyle != null) {
        print("Warning: Light map style missing, falling back to dark style.");
        styleToApply = widget.darkMapStyle;
      } else {
         print("No suitable map style found for $currentThemeBrightness. Using default map.");
      }
    }

     if (styleToApply != null) {
      try {
        await _mapController!.setMapStyle(styleToApply);
        _currentMapBrightness = currentThemeBrightness; // Update tracked brightness
        print("Map style applied successfully for $currentThemeBrightness.");
      } catch (e) {
        print("Error applying map style: $e");
         _currentMapBrightness = null; // Reset on error
      }
    } else {
       try {
        await _mapController!.setMapStyle(null); // Explicitly set default style
        _currentMapBrightness = currentThemeBrightness;
        print("Applied default map style for $currentThemeBrightness.");
      } catch (e) {
        print("Error applying default map style: $e");
        _currentMapBrightness = null; // Reset on error
      }
    }
  }

  // --- Function to launch navigation ---
  Future<void> _launchNavigation(Doctor doctor) async {
    if (widget.currentUserPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location not available to start navigation.")),
      );
      return;
    }

    // Construct the Google Maps directions URL
    // More universal approach: Use query parameter which works on both platforms
    final query = Uri.encodeComponent('${doctor.latitude},${doctor.longitude}');
    final mapUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    // Platform-specific URLs (optional, query usually works well)
    // final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving';
    // final String appleMapsUrl = 'https://maps.apple.com/?saddr=$originLat,$originLng&daddr=$destLat,$destLng&dirflg=d';

    // Uri uriToLaunch = Uri.parse(Platform.isIOS ? appleMapsUrl : googleMapsUrl); // Requires Platform import
    Uri uriToLaunch = mapUrl; // Use the query-based URL for broader compatibility

    if (await canLaunchUrl(uriToLaunch)) {
      await launchUrl(uriToLaunch, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $uriToLaunch');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open maps application for directions.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    // --- Handle Location Loading/Error ---
    if (widget.isLoadingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.primaryColor),
            const SizedBox(height: 10),
            const Text("Getting your location..."),
          ],
        ),
      );
    }
    if (widget.locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, color: errorColor, size: 40),
              const SizedBox(height: 10),
              Text(
                'Could not get location:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.locationError!.replaceFirst('Exception: ', ''), // Clean up message
                textAlign: TextAlign.center,
                style: TextStyle(color: errorColor),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: widget.onRetryLocation, // Use callback
                style: ElevatedButton.styleFrom(
                  backgroundColor: errorColor, // Use error color for button
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
              // Offer to open settings
              if (widget.locationError != null &&
                  (widget.locationError!.contains('permanently denied') ||
                      widget.locationError!.contains('disabled')))
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: TextButton(
                    onPressed: widget.locationError!.contains('disabled')
                        ? Geolocator.openLocationSettings // Open device location settings
                        : Geolocator.openAppSettings, // Open app settings
                    child: Text(
                      widget.locationError!.contains('disabled')
                          ? 'Open Location Settings'
                          : 'Open App Settings',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // --- DEBUGGING: Log received doctors ---
    // print("[HomeMapView] Received ${widget.doctors.length} doctors. Checking locations:");
    // widget.doctors.forEach((doc) {
    //   print("  - ID: ${doc.id}, Name: ${doc.name}, Lat: ${doc.latitude}, Lng: ${doc.longitude}");
    // });
    // print("--- End of received doctors list ---");

    // Filter doctors who have a valid location
    final doctorsWithLocation = widget.doctors.where((doc) {
      // Check if latitude and longitude are valid numbers and not the default 0.0
      return doc.latitude != 0.0 && doc.longitude != 0.0 &&
             doc.latitude.isFinite && doc.longitude.isFinite;
    }).toList();
    // print("[HomeMapView] Filtered down to ${doctorsWithLocation.length} doctors with valid locations."); // Log count after filtering

    // Create map markers
    final Set<Marker> markers = doctorsWithLocation.map((doctor) {
      // Use the direct latitude and longitude fields
      // DEBUG: Confirming marker creation
      // print("  -> Creating marker for ${doctor.name} at ${doctor.latitude}, ${doctor.longitude}");
      return Marker(
        markerId: MarkerId(doctor.id),
        position: LatLng(doctor.latitude, doctor.longitude),
        // Remove the default infoWindow
        // infoWindow: InfoWindow(...),
        onTap: () {
          // When marker is tapped, update the selected doctor state
          // and potentially move the camera slightly to ensure the card is visible
          setState(() {
            _selectedDoctor = doctor;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(
              LatLng(doctor.latitude, doctor.longitude))); // Center on tapped marker
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    }).toSet();

    // --- Determine Initial Camera Position ---
    LatLng initialCameraTarget;
    double initialZoom;

    if (widget.currentUserPosition != null) {
      initialCameraTarget = LatLng(
        widget.currentUserPosition!.latitude,
        widget.currentUserPosition!.longitude,
      );
      initialZoom = 14.0;
    } else {
      // Fallback if no user location
      initialCameraTarget = const LatLng(39.8283, -98.5795); // Center of US
      initialZoom = 4.0;
    }

    // --- Determine Initial Map Style based on current theme ---
    String? initialStyleString;
    final currentBrightness = Theme.of(context).brightness;
    if (currentBrightness == Brightness.dark && widget.darkMapStyle != null) {
      initialStyleString = widget.darkMapStyle;
    } else if (currentBrightness == Brightness.light && widget.lightMapStyle != null) {
      initialStyleString = widget.lightMapStyle;
    } else {
      // Fallback logic if one style is missing but the other exists
      if (currentBrightness == Brightness.dark && widget.lightMapStyle != null) {
        initialStyleString = widget.lightMapStyle; // Fallback to light
      } else if (currentBrightness == Brightness.light && widget.darkMapStyle != null) {
        initialStyleString = widget.darkMapStyle; // Fallback to dark
      }
      // If both are null, initialStyleString remains null (default map)
    }

    // --- UI Structure with Stack for Overlay ---
    return Stack(
      children: [
        // --- Map Widget ---
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialCameraTarget,
            zoom: initialZoom,
          ),
          markers: markers,
          style: initialStyleString, // Apply initial style directly
          mapType: MapType.normal,
          myLocationEnabled: true, // Show blue dot for user location
          myLocationButtonEnabled: false, // Disable default button (using custom one below)
          zoomControlsEnabled: true, // Keep zoom controls
          mapToolbarEnabled: false, // Disable default map toolbar (optional)
          compassEnabled: false, // Disable compass (optional)
          onMapCreated: (GoogleMapController controller) async {
            // Only assign controller once
            if (_mapController == null) {
                 _mapController = controller;
                 print("Map created. Controller assigned.");
                 // Apply initial style (or style based on theme change)
                 await _applyMapStyleBasedOnTheme();

                 // If user location was already available when map created, move camera
                 if (widget.currentUserPosition != null && mounted) {
                     print("Animating camera to user location on map creation.");
                     controller.animateCamera(
                        CameraUpdate.newLatLngZoom(
                        LatLng(widget.currentUserPosition!.latitude, widget.currentUserPosition!.longitude),
                        14.0,
                        ),
                    );
                 } else {
                     print("User location not available on map creation, using default position.");
                 }
            }
          },
          onTap: (_) {
            // When tapping anywhere else on the map, deselect the doctor
            setState(() {
              _selectedDoctor = null;
            });
          },
        ),

        // --- Custom Doctor Info Card Overlay ---
        if (_selectedDoctor != null)
          _buildDoctorInfoCard(_selectedDoctor!),

        // --- Custom Location Button ---
        Positioned(
          bottom: (_selectedDoctor != null) ? 110 : 20, // Adjust position based on card visibility
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'myLocationButton', // Unique hero tag
            tooltip: 'My Location',
            onPressed: () {
              if (widget.currentUserPosition != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(widget.currentUserPosition!.latitude, widget.currentUserPosition!.longitude),
                    14.0,
                  ),
                );
              }
            },
            backgroundColor: Theme.of(context).cardColor,
            child: Icon(Icons.my_location, color: Theme.of(context).primaryColor),
          ),
        ),
      ],
    );
  }

  // --- Widget Builder for the Custom Info Card ---
  Widget _buildDoctorInfoCard(Doctor doctor) {
    final theme = Theme.of(context);
    return Positioned(
      bottom: 20, // Position the card at the bottom
      left: 15,
      right: 15,
      child: GestureDetector(
        onTap: () {
          // Allow tapping the card to go to details screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DoctorDetails(doctorId: doctor.id)),
          );
        },
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Doctor Image
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: doctor.imageUrl.isNotEmpty
                      ? NetworkImage(doctor.imageUrl)
                      : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
                  onBackgroundImageError: (exception, stackTrace) {
                    // Optionally handle image loading errors, e.g., show an icon
                    print("Error loading image for card: $exception");
                  },
                ),
                const SizedBox(width: 12),
                // Doctor Info Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(doctor.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(doctor.specialty, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
                          const SizedBox(width: 4),
                          Text(doctor.rating.toStringAsFixed(1), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Icon(Icons.location_on, color: Colors.grey.shade500, size: 16),
                          Expanded(child: Text(doctor.address, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Directions Button
                IconButton(
                  icon: Icon(Icons.directions, color: theme.primaryColor, size: 30),
                  tooltip: 'Get Directions',
                  onPressed: () => _launchNavigation(doctor),
                ),
              ],
            ),
          )
          ),
      ),
    );
  }
}