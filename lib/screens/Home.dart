// lib/screens/Home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

import '/models/doctor.dart';
import '/widgets/doctor_list_item.dart';
import 'Appointments.dart';
import 'DoctorDetails.dart';
import 'InitLogin.dart';
import 'Profile.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isGuest = false;
  int _selectedIndex = 0;
  String? _loggedInUserId;
  static const String _prefsKeyAppointments = 'user_appointments_cache';
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _filteredDoctors = [];
  String? _selectedSpecialtyFilter;
  String? _selectedPredefinedFilter;
  final List<String> _predefinedFilters = [
    'All', 'Favorites', 'Map', 'Dermatology', 'Cardiology', 'Pediatrics',
  ];
  List<Doctor> _doctors = [];
  List<Doctor> _favoriteDoctors = [];
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;
  Set<String> _userFavoriteIds = {};
  final Set<String> _togglingFavorite = {};

  // --- Location and Map ---
  Position? _currentUserPosition; // Holds user's location
  bool _isLoadingLocation = false; // Tracks location fetching
  String? _locationError; // Holds location-specific errors
  GoogleMapController? _mapController; 

  @override
  void initState() {
    super.initState();
    _selectedPredefinedFilter = _predefinedFilters.first;
    _initializeHome();
    _searchController.addListener(_onSearchChanged);
    _loadMapStyle();
  }

  String? _loadedMapStyle;
  Future<void> _loadMapStyle() async {
    _loadedMapStyle = await rootBundle.loadString('assets/map_style.json');
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }

  // --- Initialization and User Status ---
  Future<void> _initializeHome() async {
    await _loadUserStatus();
    if (mounted) {
      _showWelcomeSnackBar();
      if (_loggedInUserId != null || _isGuest) {
        await _fetchDoctors(); // Fetch doctors initially
      } else {
        setState(() {
          _isLoadingDoctors = false;
          _errorLoadingDoctors = "Please log in to view doctors.";
        });
      }
    }
  }

  Future<void> _loadUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isGuest = prefs.getBool('isGuest') ?? false;
    String? userId = prefs.getString('loggedInUserId');
    if (mounted) {
      setState(() {
        _isGuest = isGuest;
        _loggedInUserId = userId;
      });
    }
  }

  void _showWelcomeSnackBar() {
    if (!mounted) return;
    final message = _isGuest ? "Browsing as Guest" : "Welcome!";
    final snackBar = SnackBar(
      content: Text(
        message, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      duration: const Duration(seconds: 3),
      backgroundColor: _isGuest ? Colors.orangeAccent : Colors.blueAccent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 70.0, left: 20.0, right: 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // --- Specialties and Filtering ---
  Set<String> _getUniqueSpecialties() {
    // Get unique specialties only from non-favorite doctors if needed, or all
    return _doctors.map((doctor) => doctor.specialty).toSet();
  }

  void _onSearchChanged() {
    // Don't filter if map is active
    if (_selectedPredefinedFilter != 'Map') {
      _filterDoctors();
    }
  }

  void _onPredefinedFilterSelected(String filter) {
     bool switchingToMap = filter == 'Map';
     bool switchingFromMap = _selectedPredefinedFilter == 'Map' && filter != 'Map';

     setState(() {
       _selectedPredefinedFilter = filter;
       // Reset specialty only if switching away from Map to a non-Map list filter
       if (switchingFromMap || (filter != 'Map' && filter != 'Favorites')) {
          _selectedSpecialtyFilter = null;
       }
     });

     if (switchingToMap) {
        // Fetch location when map is selected
        _getCurrentLocation();
        // No need to call _filterDoctors for map view
     } else {
        // Filter list view if switching to a non-map filter
        _filterDoctors();
     }
  }

  void _onSpecialtyFilterSelected(String? specialty) {
     if (_selectedPredefinedFilter == 'Map') return; // Ignore if map is active
     setState(() {
       _selectedSpecialtyFilter = specialty;
       if (specialty != null) { _selectedPredefinedFilter = 'All'; }
     });
     _filterDoctors();
  }

  // --- List Filtering Logic ---
  void _filterDoctors() {
    if (!mounted || _selectedPredefinedFilter == 'Map') return; // Don't filter if map is active

    final lowerCaseQuery = _searchController.text.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(_doctors); // Start with the master list

    // 1. Apply Predefined Filter (excluding 'Map')
    if (_selectedPredefinedFilter != null && _selectedPredefinedFilter != 'All' && _selectedPredefinedFilter != 'Map') {
      if (_selectedPredefinedFilter == 'Favorites') {
        tempFilteredList = tempFilteredList.where((doctor) => doctor.isFavorite).toList();
      } else {
        // Filter by specialty
        tempFilteredList = tempFilteredList.where((doctor) =>
            doctor.specialty.toLowerCase() == _selectedPredefinedFilter!.toLowerCase()).toList();
      }
    }

    // 2. Apply Dropdown Specialty Filter (Only if 'Favorites' button is NOT active)
    if (_selectedSpecialtyFilter != null && _selectedPredefinedFilter != 'Favorites') {
      tempFilteredList = tempFilteredList.where((doctor) =>
          doctor.specialty == _selectedSpecialtyFilter).toList();
    }

    // 3. Apply Text Search Filter (applied last)
    if (lowerCaseQuery.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((doctor) {
        final lowerCaseName = doctor.name.toLowerCase();
        final lowerCaseSpecialty = doctor.specialty.toLowerCase();
        return lowerCaseName.contains(lowerCaseQuery) ||
               lowerCaseSpecialty.contains(lowerCaseQuery);
      }).toList();
    }

    // Update the state variable that the main list view uses
    setState(() {
      _filteredDoctors = tempFilteredList;
    });
  }

  // --- Data Fetching (Fetch Doctors + User Favorites) ---
  Future<void> _fetchDoctors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDoctors = true;
      _errorLoadingDoctors = null;
      // Don't clear _doctors immediately if we want map to show old data while loading
      // _doctors = [];
      _filteredDoctors = [];
      _favoriteDoctors = [];
      _userFavoriteIds = {};
    });

    List<Doctor> previouslyFetchedDoctors = List.from(_doctors); // Keep old data temporarily

    try {
      // 1. Fetch User's Favorite IDs (only if logged in)
      if (_loggedInUserId != null) {
        try {
           DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_loggedInUserId!).get();
           if (userDoc.exists && userDoc.data() != null) {
              final data = userDoc.data() as Map<String, dynamic>;
              if (data.containsKey('favoriteDoctorIds') && data['favoriteDoctorIds'] is List) {
                 _userFavoriteIds = List<String>.from(data['favoriteDoctorIds']).toSet();
              }
           }
        } catch (e) { print("Error fetching user favorites: $e"); }
      }

      // 2. Fetch All Doctors
      QuerySnapshot doctorSnapshot = await FirebaseFirestore.instance.collection('doctors').get();

      if (mounted) {
        // 3. Process Doctors and Merge Favorite Status
        final List<Doctor> processedDoctors = doctorSnapshot.docs.map((doc) {
          Doctor doctor = Doctor.fromFirestore(doc);
          bool isFav = _userFavoriteIds.contains(doctor.id);
          // Ensure all fields from your Doctor model are included here
          return Doctor(
             id: doctor.id, name: doctor.name, specialty: doctor.specialty,
             address: doctor.address, phone: doctor.phone, imageUrl: doctor.imageUrl,
             rating: doctor.rating,  // Make sure reviews is in your model
             location: doctor.location, bio: doctor.bio,
            // workingHours: doctor.workingHours, // Make sure workingHours is in your model
             isFavorite: isFav,
          );
        }).toList();

        // 4. Update State
        setState(() {
          _doctors = processedDoctors; // Update the master list
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList(); // Update derived favorites list
          _isLoadingDoctors = false;
          _errorLoadingDoctors = null;
          // Apply filters only if map is not selected
          if (_selectedPredefinedFilter != 'Map') {
             _filterDoctors();
          } else {
             // If map is selected, ensure _filteredDoctors is cleared or ignored
             _filteredDoctors = []; // Or simply don't call _filterDoctors
          }
        });
      }
    } catch (e, stackTrace) {
      print("Error fetching doctors: $e\n$stackTrace");
      if (mounted) {
        String errorMessage = 'Failed to load doctors.';
        if (e is FirebaseException) {
          errorMessage += ' (Code: ${e.code})';
        } else if (e is FormatException ||
            e is TypeError ||
            e.toString().contains('toDouble')) {
          errorMessage =
              'Error processing doctor data. Please check data format.';
          print(
            "Data processing error likely related to Firestore data types.",
          );
        } else {
          errorMessage += ' Please try again.';
        }
        setState(() {
          _errorLoadingDoctors = errorMessage;
          _isLoadingDoctors = false;
          _doctors = previouslyFetchedDoctors; // Revert to old data on error if available
          _filteredDoctors = [];
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList(); // Update based on potentially old data
        });
      }
    }
  }

  // --- Toggle Favorite Status ---
  Future<void> _toggleFavoriteStatus(String doctorId, bool currentIsFavorite) async {
    if (_loggedInUserId == null || _togglingFavorite.contains(doctorId)) return;
    if (!mounted) return;
    setState(() { _togglingFavorite.add(doctorId); });

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(_loggedInUserId!);
    final updateData = currentIsFavorite
        ? {'favoriteDoctorIds': FieldValue.arrayRemove([doctorId])}
        : {'favoriteDoctorIds': FieldValue.arrayUnion([doctorId])};

    try {
      await userDocRef.update(updateData);
      if (mounted) {
        currentIsFavorite ? _userFavoriteIds.remove(doctorId) : _userFavoriteIds.add(doctorId);
        List<Doctor> updatedDoctors = _doctors.map((doctor) {
          if (doctor.id == doctorId) {
            // Ensure all fields are included when creating the new Doctor instance
            return Doctor(
               id: doctor.id, name: doctor.name, specialty: doctor.specialty,
               address: doctor.address, phone: doctor.phone, imageUrl: doctor.imageUrl,
               rating: doctor.rating,  // Make sure reviews is included
               location: doctor.location, bio: doctor.bio,
              // workingHours: doctor.workingHours, // Make sure workingHours is included
               isFavorite: !currentIsFavorite,
            );
          }
          return doctor;
        }).toList();
        setState(() {
          _doctors = updatedDoctors;
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList();
          // Re-apply filters only if map is not selected
          if (_selectedPredefinedFilter != 'Map') {
             _filterDoctors();
          }
        });
      }
    } catch (e) {
      print("Error toggling favorite: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update favorites: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() { _togglingFavorite.remove(doctorId); });
      }
    }
  }

  // --- Logout ---
  Future<void> _handleLogout() async {
    bool confirmLogout = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: const Text('Logout'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    ) ?? false;

    if (confirmLogout) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('loggedInUserId');
      if (userId != null) {
         await prefs.remove(_prefsKeyAppointments + userId);
         print("Local appointments cache cleared for user $userId.");
      }
      await prefs.remove('loggedInUserId');
      await prefs.setBool('isGuest', false);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const InitLogin()), (Route<dynamic> route) => false);
    }
  }

  // --- Navigation ---
  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
  }

  // --- Body Building Logic ---
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _homeScreenBody();
      case 1: return _isGuest ? _guestModeNotice("view appointments") : const Appointments();
      case 2: return _isGuest ? _guestModeNotice("view your profile") : const Profile();
      default: return _homeScreenBody();
    }
  }

  Widget _guestModeNotice(String action) {
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Please log in to $action.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InitLogin())); },
              child: const Text('Go to Login'),
            )
          ],
        ),
      ),
    );
  }

 // --- Builds the main content for the Home tab ---
  Widget _homeScreenBody() {
    return Column(
      children: [
        // --- Fixed Top Section ---
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 5.0),
          child: _searchSection(),
        ),
        _buildPredefinedFilters(),

        // --- Conditional Content Area ---
        Expanded(
          child: _selectedPredefinedFilter == 'Map'
              ? _buildMapView() // Show Map View
              : _buildListView(), // Show List View
        ),
      ],
    );
  }
  

  // Builds the scrollable list view part
  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _fetchDoctors,
      child: CustomScrollView(
        slivers: <Widget>[
          // Header for Main List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 15, left: 16, right: 16, bottom: 10),
              child: Text(
                _getDoctorListTitle(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Main Doctor List (Handles all display including favorites via filter)
          _buildSliverDoctorList(),
          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
  // --- NEW: Get User Location ---
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // 2. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      // 3. Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high); // Or .medium for less battery usage

      if (mounted) {
        setState(() {
          _currentUserPosition = position;
          _isLoadingLocation = false;
        });
        // Animate map to the new location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0, // Zoom in closer when user location is found
          ),
        );
      }
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _isLoadingLocation = false;
        });
      }
    }
  }

  // --- UPDATED: Builds the Google Map view part ---
  Widget _buildMapView() {
    // --- Handle Location Loading/Error ---
    if (_isLoadingLocation) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Getting your location...")],));
    }
    if (_locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                'Could not get location:',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                // Clean up the error message slightly
                _locationError!.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _getCurrentLocation, // Allow retry
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
              // Optionally add a button to open app settings for permission errors
              if (_locationError != null && (_locationError!.contains('permanently denied') || _locationError!.contains('disabled')))
                 Padding(
                   padding: const EdgeInsets.only(top: 10.0),
                   child: TextButton(
                     // Decide action based on error type
                     onPressed: _locationError!.contains('disabled')
                        ? Geolocator.openLocationSettings // Open device location settings
                        : Geolocator.openAppSettings,    // Open app-specific settings
                     child: Text(_locationError!.contains('disabled')
                        ? 'Open Location Settings'
                        : 'Open App Settings'),
                   ),
                 ),
            ],
          ),
        ),
      );
    }
    // --- End Location Handling ---
    // Filter doctors who have a valid location (same as before)
   final doctorsWithLocation = _doctors.where((doc) {
        // Check if location is not null AND latitude/longitude are valid numbers
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorDetails(doctorId: doctor.id)));
          }
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }).toSet();

    // --- Determine Initial Camera Position ---
    // Use user's location if available, otherwise a default
LatLng initialCameraTarget;
    double initialZoom;

    if (_currentUserPosition != null) {
      initialCameraTarget = LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude);
      initialZoom = 14.0; // Zoom in closer if user location is known
    } else {
      // Absolute fallback (e.g., center of a country/region) if no user location
      // You might want to adjust this default to your target region
      initialCameraTarget = const LatLng(39.8283, -98.5795); // Center of US
      initialZoom = 4.0; // Zoom out if using default

    }    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialCameraTarget,
        zoom: initialZoom,
      ),
      markers: markers,
      mapType: MapType.normal,
      myLocationEnabled: true, // Show blue dot for user location
      myLocationButtonEnabled: true, // Show button to center on user
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      // Get the controller when the map is created
      onMapCreated: (GoogleMapController controller) async {
        _mapController = controller;

        if (_loadedMapStyle != null) {
          try {
            await controller.setMapStyle(_loadedMapStyle!);
             print("Map style applied successfully in onMapCreated.");
          } catch (e) {
             print("Error applying map style in onMapCreated: $e");
          }
        } else {
           print("Map style not loaded yet when map was created.");
        }
        // If user location was already available when map created, move camera
        if (_currentUserPosition != null) {
           controller.animateCamera(
             CameraUpdate.newLatLngZoom(
               LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
               14.0,
             ),
           );
        }
      },
    );
  }

  String _getDoctorListTitle() {
     // Title doesn't apply when map is shown, but we keep the logic
     bool isAnyFilterActive = _searchController.text.isNotEmpty ||
                              _selectedSpecialtyFilter != null ||
                              (_selectedPredefinedFilter != null && _selectedPredefinedFilter != 'All' && _selectedPredefinedFilter != 'Map');
     if (_selectedPredefinedFilter == 'Favorites') {
        return 'Favorite Doctors';
     }
     // Don't show 'Filtered Doctors' if only 'Map' was previously selected
     if (isAnyFilterActive) {
        return 'Filtered Doctors';
     }
     return 'Available Doctors';
  }

  // --- Build Main Doctor List ---
  Widget _buildSliverDoctorList() {
    if (_isLoadingDoctors && _doctors.isEmpty) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }
    if (_errorLoadingDoctors != null && _doctors.isEmpty) {
      return SliverFillRemaining(child: _buildErrorWidget());
    }
    // Check _filteredDoctors for emptiness
    if (_filteredDoctors.isEmpty) {
      if (_selectedPredefinedFilter == 'Favorites' && !_isGuest) {
         return SliverToBoxAdapter(child: _buildEmptyFavoritesMessage());
      }
      // Show general empty message if filters active or no doctors exist
      if (_selectedPredefinedFilter != 'All' || _selectedSpecialtyFilter != null || _searchController.text.isNotEmpty || _doctors.isEmpty) {
         return SliverToBoxAdapter(child: _buildEmptyListWidget());
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    // Build the list using _filteredDoctors
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final doctor = _filteredDoctors[index];
          return DoctorListItem(
            doctor: doctor,
            onFavoriteToggle: _loggedInUserId != null ? _toggleFavoriteStatus : null,
            isTogglingFavorite: _togglingFavorite.contains(doctor.id),
          );
        },
        childCount: _filteredDoctors.length,
      ),
    );
  }

  // --- Helper Widgets for List States ---
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 50),
            const SizedBox(height: 10),
            Text(
              _errorLoadingDoctors ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700], fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _fetchDoctors,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListWidget() {
    // Message shown when filters result in an empty list
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
        child: Text(
          _doctors.isEmpty
              ? 'No doctors found at the moment.' 
              : 'No doctors match your current filters.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  // --- Helper for Empty Favorites Message ---
  Widget _buildEmptyFavoritesMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
      child: Center(
        child: Text(
          'You haven\'t added any favorite doctors yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  // Builds the horizontal list of predefined filter chips
  Widget _buildPredefinedFilters() {
    bool mapFilterActive = _selectedPredefinedFilter == 'Map';

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _predefinedFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _predefinedFilters[index];
          final isSelected = filter == _selectedPredefinedFilter;
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) { _onPredefinedFilterSelected(filter); }
            },
            showCheckmark: false,
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.9),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : mapFilterActive && filter != 'Map'
                      ? Colors.grey.shade500
                      : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: Colors.grey.shade200,
            shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
            elevation: isSelected ? 2 : 0,
          );
        },
      ),
    );
  }

  // --- Search Section ---
  Widget _searchSection() {
    bool mapFilterActive = _selectedPredefinedFilter == 'Map';

    return TextField(
      controller: _searchController,
      enabled: !mapFilterActive, // Disable TextField when map is active
      style: TextStyle(color: mapFilterActive ? Colors.grey : null),
      decoration: InputDecoration(
        filled: true,
        fillColor: mapFilterActive ? Colors.grey.shade100 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
        hintText: mapFilterActive ? 'Map View Active' : 'Search Doctor or Specialty...',
        hintStyle: TextStyle(
            color: mapFilterActive ? Colors.grey.shade500 : const Color(0xffDDDADA),
            fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 15, right: 10),
          child: Icon(Icons.search, size: 22, color: mapFilterActive ? Colors.grey : null),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clear button
            if (_searchController.text.isNotEmpty && !mapFilterActive)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                tooltip: 'Clear Search',
                onPressed: () { _searchController.clear(); },
              )
            else if (mapFilterActive)
              const SizedBox(width: 48),

            // Divider
            SizedBox(
               height: 30,
               child: VerticalDivider(color: mapFilterActive ? Colors.grey.shade300 : Colors.grey, indent: 5, endIndent: 5, thickness: 0.7),
            ),
            // Specialty Filter Popup
            PopupMenuButton<String?>(
              icon: Icon(
                Icons.filter_list, size: 24,
                color: mapFilterActive
                    ? Colors.grey.shade400 
                    : _selectedSpecialtyFilter == null
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
              ),
              tooltip: mapFilterActive ? null : 'Filter by Specialty',
              onSelected: mapFilterActive ? null : _onSpecialtyFilterSelected, // Disable selection
              itemBuilder: mapFilterActive
                  ? (BuildContext context) => <PopupMenuEntry<String?>>[] 
                  : (BuildContext context) {
                      Set<String> specialties = _getUniqueSpecialties();
                      List<PopupMenuEntry<String?>> menuItems = [];
                      menuItems.add(
                        PopupMenuItem<String?>(
                          value: null,
                          child: Text('All Specialties', style: TextStyle(fontWeight: _selectedSpecialtyFilter == null ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                      if (specialties.isNotEmpty) { menuItems.add(const PopupMenuDivider()); }
                      var sortedSpecialties = specialties.toList()..sort();
                      for (String specialty in sortedSpecialties) {
                        menuItems.add(
                          PopupMenuItem<String?>(
                            value: specialty,
                            child: Text(specialty, style: TextStyle(fontWeight: _selectedSpecialtyFilter == specialty ? FontWeight.bold : FontWeight.normal)),
                          ),
                        );
                      }
                      return menuItems;
                    },
            ),
            const SizedBox(width: 8),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
         enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(30),
           borderSide: BorderSide(color: Colors.grey.shade300),
         ),
         focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(30),
           borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
         ),
         disabledBorder: OutlineInputBorder( // Style when disabled
           borderRadius: BorderRadius.circular(30),
           borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Appointment'),
        centerTitle: true,
        elevation: 1,
        actions: [
          if (!_isGuest && _loggedInUserId != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _handleLogout,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  } 
}
