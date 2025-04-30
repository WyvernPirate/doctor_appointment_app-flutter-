// lib/widgets/home/home_map_view.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '/models/doctor.dart';
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

    // Filter doctors who have a valid location
    final doctorsWithLocation = widget.doctors.where((doc) {
      return doc.location != null &&
          doc.location!.latitude.isFinite &&
          doc.location!.longitude.isFinite;
    }).toList();

    // Create map markers
    final Set<Marker> markers = doctorsWithLocation.map((doctor) {
      final lat = doctor.location!.latitude;
      final lng = doctor.location!.longitude;
      return Marker(
        markerId: MarkerId(doctor.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: doctor.name,
          snippet: doctor.specialty,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DoctorDetails(doctorId: doctor.id),
              ),
            );
          },
        ),
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

    // --- Map Widget ---
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialCameraTarget,
        zoom: initialZoom,
      ),
      markers: markers,
      mapType: MapType.normal,
      myLocationEnabled: true, // Show blue dot for user location
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      onMapCreated: (GoogleMapController controller) async {
        // Only assign controller once
        if (_mapController == null) {
             _mapController = controller;
             print("Map created. Applying initial style...");
             await _applyMapStyleBasedOnTheme(); // Apply style immediately after creation

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
    );
  }
}
