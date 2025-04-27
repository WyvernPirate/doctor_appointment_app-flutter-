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
  // --- User & Navigation State ---
  bool _isGuest = false;
  int _selectedIndex = 0;
  String? _loggedInUserId;
  static const String _prefsKeyAppointments = 'user_appointments_cache';

  // --- Search & Filtering State ---
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _filteredDoctors = [];
  String? _selectedSpecialtyFilter;
  String? _selectedPredefinedFilter;
  final List<String> _predefinedFilters = [
    'All', 'Favorites', 'Map', 'Dermatology', 'Cardiology', 'Pediatrics',
    // Add more predefined specialties if needed
  ];

  // --- Doctor Data State ---
  List<Doctor> _doctors = []; 
  List<Doctor> _favoriteDoctors = []; 
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;
  Set<String> _userFavoriteIds = {}; 
  final Set<String> _togglingFavorite = {}; 

  // --- Location and Map State ---
  Position? _currentUserPosition;
  bool _isLoadingLocation = false;
  String? _locationError; 
  GoogleMapController? _mapController;
  String? _lightMapStyle; 
  String? _darkMapStyle; 
  Brightness? _currentMapBrightness;

  @override
  void initState() {
    super.initState();
    _selectedPredefinedFilter = _predefinedFilters.first; // Default to 'All'
    _initializeHome();
    _searchController.addListener(_onSearchChanged);
    _loadMapStyles();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --- Load both map styles ---
  Future<void> _loadMapStyles() async {
    try {
      _lightMapStyle = await rootBundle.loadString('lib/assets/map_style.json');
      _darkMapStyle = await rootBundle.loadString(
        'lib/assets/map_style_dark.json',
      );
      // Apply style if map is already created and context is available
      if (mounted && _mapController != null) {
        await _applyMapStyleBasedOnTheme();
      }
    } catch (e) {
      print("Error loading map styles: $e");
    }
  }

  // ---Apply map style based on current theme ---
  Future<void> _applyMapStyleBasedOnTheme() async {
    // Ensure map controller, styles, and context are available
    if (_mapController == null ||
        !mounted ||
        (_lightMapStyle == null && _darkMapStyle == null)) {
      print(
        "Map style application skipped: Controller null, not mounted, or styles not loaded.",
      );
      return;
    }

    final currentThemeBrightness = Theme.of(context).brightness;
    if (_currentMapBrightness == currentThemeBrightness) {
      print(
        "Map style skipped: Brightness hasn't changed ($currentThemeBrightness).",
      );
      return;
    }

    print("Attempting to apply map style for theme: $currentThemeBrightness");

    String? styleToApply;
    if (currentThemeBrightness == Brightness.dark && _darkMapStyle != null) {
      styleToApply = _darkMapStyle;
      print("Selected dark map style.");
    } else if (currentThemeBrightness == Brightness.light &&
        _lightMapStyle != null) {
      styleToApply = _lightMapStyle;
      print("Selected light map style.");
    } else {
      // Fallback logic if one style is missing but the other exists
      if (currentThemeBrightness == Brightness.dark && _lightMapStyle != null) {
        print("Warning: Dark map style missing, falling back to light style.");
        styleToApply = _lightMapStyle;
      } else if (currentThemeBrightness == Brightness.light &&
          _darkMapStyle != null) {
        print("Warning: Light map style missing, falling back to dark style.");
        styleToApply = _darkMapStyle;
      } else {
        print(
          "No suitable map style found for $currentThemeBrightness. Using default map.",
        );
      }
    }

    if (styleToApply != null) {
      try {
        await _mapController!.setMapStyle(styleToApply);
        _currentMapBrightness =
            currentThemeBrightness; // Update tracked brightness
        print("Map style applied successfully for $currentThemeBrightness.");
      } catch (e) {
        print("Error applying map style: $e");
        _currentMapBrightness = null;
      }
    } else {
      try {
        await _mapController!.setMapStyle(null); // Explicitly set default style
        _currentMapBrightness = currentThemeBrightness;
        print("Applied default map style for $currentThemeBrightness.");
      } catch (e) {
        print("Error applying default map style: $e");
        _currentMapBrightness = null;
      }
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mapController != null) {
      _applyMapStyleBasedOnTheme();
    }
  }

  // --- Initialization and User Status ---
  Future<void> _initializeHome() async {
    await _loadUserStatus();
    if (mounted) {
      _showWelcomeSnackBar();
      if (_loggedInUserId != null || _isGuest) {
        await _fetchDoctors(); // Fetch doctors
      } else {
        setState(() {
          _isLoadingDoctors = false;
          _errorLoadingDoctors = "User status unclear. Please restart the app.";
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
    final theme = Theme.of(context);
    final snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color:
              _isGuest
                  ? Colors.black87
                  : theme
                      .colorScheme
                      .onPrimary, 
        ),
      ),
      duration: const Duration(seconds: 3),
      backgroundColor:
          _isGuest
              ? Colors.orangeAccent
              : theme.colorScheme.primary, // Use theme color
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 70.0, left: 20.0, right: 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // --- Specialties and Filtering ---
  Set<String> _getUniqueSpecialties() {
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
    bool switchingFromMap =
        _selectedPredefinedFilter == 'Map' && filter != 'Map';

    setState(() {
      _selectedPredefinedFilter = filter;
      if (switchingFromMap ||
          (filter != 'Map' && filter != 'Favorites' && filter != 'All')) {
        _selectedSpecialtyFilter = null;
      }
      if (filter != 'Map' && filter != 'Favorites' && filter != 'All') {
        _searchController
            .clear(); 
      }
    });

    if (switchingToMap) {
      // Fetch location when map is selected
      _getCurrentLocation();
      // Clear list filters when switching to map
      setState(() {
        _filteredDoctors = [];
      });
    } else {
      _filterDoctors();
    }
  }

  void _onSpecialtyFilterSelected(String? specialty) {
    if (_selectedPredefinedFilter == 'Map') return; 
    setState(() {
      _selectedSpecialtyFilter = specialty;
      if (specialty != null && _selectedPredefinedFilter != 'Favorites') {
        _selectedPredefinedFilter = 'All';
      }
      _searchController.clear(); // Clear search when specialty dropdown is used
    });
    _filterDoctors();
  }

  // --- List Filtering Logic ---
  void _filterDoctors() {
    if (!mounted || _selectedPredefinedFilter == 'Map') return;

    final lowerCaseQuery = _searchController.text.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(
      _doctors,
    ); // Start with the master list

    //  Apply Predefined Filter Chip (excluding 'Map', 'All')
    if (_selectedPredefinedFilter != null &&
        _selectedPredefinedFilter != 'All' &&
        _selectedPredefinedFilter != 'Map') {
      if (_selectedPredefinedFilter == 'Favorites') {
        tempFilteredList =
            tempFilteredList.where((doctor) => doctor.isFavorite).toList();
      } else {
        // Filter by specialty chip
        tempFilteredList =
            tempFilteredList
                .where(
                  (doctor) =>
                      doctor.specialty.toLowerCase() ==
                      _selectedPredefinedFilter!.toLowerCase(),
                )
                .toList();
      }
    }

    //  Apply Dropdown Specialty Filter 
    if (_selectedSpecialtyFilter != null &&
        _selectedPredefinedFilter != 'Favorites') {
      tempFilteredList =
          tempFilteredList
              .where((doctor) => doctor.specialty == _selectedSpecialtyFilter)
              .toList();
    }

    // Apply Text Search Filter (applied last)
    if (lowerCaseQuery.isNotEmpty) {
      // Apply search only if a predefined specialty chip is NOT selected
      if (_selectedPredefinedFilter == 'All' ||
          _selectedPredefinedFilter == 'Favorites' ||
          _selectedPredefinedFilter == null) {
        tempFilteredList =
            tempFilteredList.where((doctor) {
              final lowerCaseName = doctor.name.toLowerCase();
              final lowerCaseSpecialty = doctor.specialty.toLowerCase();
              return lowerCaseName.contains(lowerCaseQuery) ||
                  lowerCaseSpecialty.contains(lowerCaseQuery);
            }).toList();
      }
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
     
      _filteredDoctors = [];
      _favoriteDoctors = [];
      _userFavoriteIds = {};
    });

    List<Doctor> previouslyFetchedDoctors = List.from(
      _doctors,
    ); // Keep old data temporarily

    try {
      // 1. Fetch User's Favorite IDs (only if logged in)
      Set<String> fetchedFavoriteIds = {};
      if (_loggedInUserId != null) {
        try {
          DocumentSnapshot userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_loggedInUserId!)
                  .get();
          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data() as Map<String, dynamic>;
            if (data.containsKey('favoriteDoctorIds') &&
                data['favoriteDoctorIds'] is List) {
              fetchedFavoriteIds =
                  List<String>.from(data['favoriteDoctorIds']).toSet();
            }
          }
        } catch (e) {
          print(
            "Error fetching user favorites: $e",
          ); 
        }
      }

      // Fetch All Doctors
      QuerySnapshot doctorSnapshot =
          await FirebaseFirestore.instance.collection('doctors').get();

      if (mounted) {
        // Process Doctors and Merge Favorite Status
        final List<Doctor> processedDoctors =
            doctorSnapshot.docs.map((doc) {
              Doctor doctor = Doctor.fromFirestore(doc);
              bool isFav = fetchedFavoriteIds.contains(doctor.id);

              return Doctor(
                id: doctor.id,
                name: doctor.name,
                specialty: doctor.specialty,
                address: doctor.address,
                phone: doctor.phone,
                imageUrl: doctor.imageUrl,
                rating: doctor.rating,
                location: doctor.location,
                bio: doctor.bio,
                // workingHours: doctor.workingHours, 
                isFavorite: isFav,
              );
            }).toList();

        //  Update State
        setState(() {
          _doctors = processedDoctors; // Update the master list
          _userFavoriteIds = fetchedFavoriteIds; 
          _favoriteDoctors =
              _doctors
                  .where((d) => d.isFavorite)
                  .toList(); // Update derived favorites list
          _isLoadingDoctors = false;
          _errorLoadingDoctors = null;
          // Apply filters only if map is not selected
          if (_selectedPredefinedFilter != 'Map') {
            _filterDoctors();
          } else {
            // If map is selected, ensure _filteredDoctors is cleared or ignored
            _filteredDoctors = [];
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
          _doctors =
              previouslyFetchedDoctors; // Revert to old data on error if available
          _filteredDoctors = []; // Clear filtered list on error
          _favoriteDoctors =
              _doctors
                  .where((d) => d.isFavorite)
                  .toList(); // Update based on potentially old data
        });
      }
    }
  }

  // --- Toggle Favorite Status ---
  Future<void> _toggleFavoriteStatus(
    String doctorId,
    bool currentIsFavorite,
  ) async {
    if (_loggedInUserId == null || _togglingFavorite.contains(doctorId)) return;
    if (!mounted) return;
    setState(() {
      _togglingFavorite.add(doctorId);
    });

    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_loggedInUserId!);
    final updateData =
        currentIsFavorite
            ? {
              'favoriteDoctorIds': FieldValue.arrayRemove([doctorId]),
            }
            : {
              'favoriteDoctorIds': FieldValue.arrayUnion([doctorId]),
            };

    try {
      await userDocRef.update(updateData);
      if (mounted) {
        // Update local state immediately for responsiveness
        final newFavoriteStatus = !currentIsFavorite;
        if (newFavoriteStatus) {
          _userFavoriteIds.add(doctorId);
        } else {
          _userFavoriteIds.remove(doctorId);
        }

        List<Doctor> updatedDoctors =
            _doctors.map((doctor) {
              if (doctor.id == doctorId) {
                return Doctor(
                  // Create a new instance with updated favorite status
                  id: doctor.id,
                  name: doctor.name,
                  specialty: doctor.specialty,
                  address: doctor.address,
                  phone: doctor.phone,
                  imageUrl: doctor.imageUrl,
                  rating: doctor.rating,
                  location: doctor.location,
                  bio: doctor.bio,
                  // workingHours: doctor.workingHours,
                  isFavorite: newFavoriteStatus,
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
        // Revert local state change on error? Optional, depends on desired UX
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update favorites: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _togglingFavorite.remove(doctorId);
        });
      }
    }
  }

  // --- Logout ---
  Future<void> _handleLogout() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    bool confirmLogout =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ), // Use theme error color
                  child: const Text('Logout'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmLogout) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('loggedInUserId');
      if (userId != null) {
        // Consider clearing other user-specific cache if needed
        await prefs.remove(_prefsKeyAppointments + userId);
        print("Local appointments cache cleared for user $userId.");
      }
      await prefs.remove('loggedInUserId');
      await prefs.setBool('isGuest', false); 
      if (!mounted) return;
      // Navigate to login screen and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const InitLogin()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- Navigation ---
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- Body Building Logic ---
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeScreenBody();
      case 1:
        return _isGuest
            ? _guestModeNotice("view appointments")
            : const Appointments();
      case 2:
        return _isGuest
            ? _guestModeNotice("view your profile")
            : const Profile();
      default:
        return _homeScreenBody(); // Fallback to home
    }
  }

  Widget _guestModeNotice(String action) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 60,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Please log in to $action.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: theme.disabledColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to login screen and remove all previous routes
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const InitLogin()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Builds the main content for the Home tab ---
  Widget _homeScreenBody() {
    return Column(
      children: [
        // --- Top Section (Search and Filters) ---
        Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 10.0,
            bottom: 5.0,
          ),
          child: _searchSection(), 
        ),
        _buildPredefinedFilters(), 
        Expanded(
          child:
              _selectedPredefinedFilter == 'Map'
                  ? _buildMapView() // Show Map View
                  : _buildListView(), // Show List View
        ),
      ],
    );
  }

  // Builds the scrollable list view part
  Widget _buildListView() {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _fetchDoctors,
      color: theme.primaryColor, // Use theme color for indicator
      child: CustomScrollView(
        slivers: <Widget>[
          // Header for Main List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 15,
                left: 16,
                right: 16,
                bottom: 10,
              ),
              child: Text(
                _getDoctorListTitle(),
                // Use theme text style
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Main Doctor List 
          _buildSliverDoctorList(),
          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // --- Get User Location ---
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. Please enable them in app settings.',
        );
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ); 

      if (mounted) {
        setState(() {
          _currentUserPosition = position;
          _isLoadingLocation = false;
        });
        // Animate map to the new location if controller is ready
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0, 
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

  // --- Google Map view ---
  Widget _buildMapView() {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    // --- Handle Location Loading/Error ---
    if (_isLoadingLocation) {
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
    if (_locationError != null) {
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
                _locationError!.replaceFirst(
                  'Exception: ',
                  '',
                ), // Clean up message
                textAlign: TextAlign.center,
                style: TextStyle(color: errorColor),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: errorColor, // Use error color for button
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
              // Offer to open settings if permission denied permanently or service disabled
              if (_locationError != null &&
                  (_locationError!.contains('permanently denied') ||
                      _locationError!.contains('disabled')))
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: TextButton(
                    onPressed:
                        _locationError!.contains('disabled')
                            ? Geolocator
                                .openLocationSettings // Open device location settings
                            : Geolocator
                                .openAppSettings, 
                    child: Text(
                      _locationError!.contains('disabled')
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
    final doctorsWithLocation =
        _doctors.where((doc) {
          return doc.location != null &&
              doc.location!.latitude.isFinite &&
              doc.location!.longitude.isFinite;
        }).toList();

    // Create map markers
    final Set<Marker> markers =
        doctorsWithLocation.map((doctor) {
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

    if (_currentUserPosition != null) {
      initialCameraTarget = LatLng(
        _currentUserPosition!.latitude,
        _currentUserPosition!.longitude,
      );
      initialZoom = 14.0;
    } else {
      // Fallback if no user location 
      initialCameraTarget = const LatLng(39.8283, -98.5795);
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
        _mapController = controller;
        print("Map created. Applying initial style...");
        await _applyMapStyleBasedOnTheme();

        if (!mounted) return;
        // If user location was already available when map created, move camera
        if (_currentUserPosition != null) {
          print("Animating camera to user location on map creation.");
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(
                _currentUserPosition!.latitude,
                _currentUserPosition!.longitude,
              ),
              14.0,
            ),
          );
        } else {
          print(
            "User location not available on map creation, using default position.",
          );
        }
      },
    );
  }

  String _getDoctorListTitle() {
    // Determine the appropriate title based on the current filter state
    bool isSearchActive = _searchController.text.isNotEmpty;
    bool isSpecialtyFilterActive = _selectedSpecialtyFilter != null;
    bool isPredefinedSpecialtyActive =
        _selectedPredefinedFilter != null &&
        _selectedPredefinedFilter != 'All' &&
        _selectedPredefinedFilter != 'Map' &&
        _selectedPredefinedFilter != 'Favorites';

    if (_selectedPredefinedFilter == 'Favorites') {
      return 'Favorite Doctors';
    }
    if (isSearchActive ||
        isSpecialtyFilterActive ||
        isPredefinedSpecialtyActive) {
      return 'Filtered Doctors';
    }
    return 'Available Doctors'; // Default title
  }

  // --- Build Main Doctor List ---
  Widget _buildSliverDoctorList() {
    final theme = Theme.of(context);

    if (_isLoadingDoctors && _doctors.isEmpty) {
      // Show loading indicator only if there's no previous data
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }
    if (_errorLoadingDoctors != null && _doctors.isEmpty) {
      // Show error only if there's no previous data
      return SliverFillRemaining(child: _buildErrorWidget());
    }
    // Check _filteredDoctors for emptiness AFTER handling loading/error for initial state
    if (!_isLoadingDoctors && _filteredDoctors.isEmpty) {
      if (_selectedPredefinedFilter == 'Favorites' && !_isGuest) {
        return SliverToBoxAdapter(child: _buildEmptyFavoritesMessage());
      }
      // Show general empty message if filters active or no doctors exist at all
      if (_selectedPredefinedFilter != 'All' ||
          _selectedSpecialtyFilter != null ||
          _searchController.text.isNotEmpty ||
          _doctors.isEmpty) {
        return SliverToBoxAdapter(child: _buildEmptyListWidget());
      }
      // If 'All' is selected, no filters active
      return const SliverToBoxAdapter(
        child: SizedBox.shrink(),
      ); // Or show a generic "No doctors available"
    }

    // Build the list using _filteredDoctors
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final doctor = _filteredDoctors[index];
        return DoctorListItem(
          // This widget should use CardTheme from main.dart
          doctor: doctor,
          onFavoriteToggle:
              _loggedInUserId != null ? _toggleFavoriteStatus : null,
          isTogglingFavorite: _togglingFavorite.contains(doctor.id),
        );
      }, childCount: _filteredDoctors.length),
    );
  }

  // --- Helper Widgets for List States ---
  Widget _buildErrorWidget() {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 50),
            const SizedBox(height: 10),
            Text(
              _errorLoadingDoctors ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: errorColor, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _fetchDoctors,
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListWidget() {
    final theme = Theme.of(context);
    // Message shown when filters result in an empty list or no doctors initially
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
        child: Text(
          _doctors.isEmpty &&
                  !_isLoadingDoctors // Check if master list is truly empty
              ? 'No doctors found at the moment.'
              : 'No doctors match your current filters.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: theme.disabledColor),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesMessage() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
      child: Center(
        child: Text(
          'You haven\'t added any favorite doctors yet.\nTap the heart icon on a doctor\'s profile to add them.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: theme.disabledColor,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // Builds the horizontal list of predefined filter chips 
  Widget _buildPredefinedFilters() {
    bool mapFilterActive = _selectedPredefinedFilter == 'Map';
    final theme = Theme.of(context); // Get theme data
    final chipTheme = theme.chipTheme; 
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

          // Determine label color based on selection and map state
          Color labelColor;
          if (isSelected) {
           
            labelColor = chipTheme.secondaryLabelStyle?.color ?? Colors.white;
          } else if (mapFilterActive && filter != 'Map') {
            labelColor =
                theme.disabledColor; // Dim if map active and not map chip
          } else {
            labelColor =
                chipTheme.labelStyle?.color ??
                theme.textTheme.bodyLarge!.color!;
          }

          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                _onPredefinedFilterSelected(filter);
              }
            },
            showCheckmark:
                chipTheme.showCheckmark ?? false, // Use theme default
            selectedColor: chipTheme.selectedColor, // Use theme color
            checkmarkColor: chipTheme.checkmarkColor, // Use theme color
            labelStyle: chipTheme.labelStyle?.copyWith(
              // Base style
              color: labelColor, // Apply calculated color
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: chipTheme.backgroundColor, // Use theme color
            shape: chipTheme.shape, // Use theme shape
            side: chipTheme.side, // Use theme border side
            elevation:
                isSelected
                    ? (chipTheme.elevation ?? 2.0)
                    : (chipTheme.pressElevation ?? 0.0),
            pressElevation: chipTheme.pressElevation,
          );
        },
      ),
    );
  }

  // --- Search Section ---
  Widget _searchSection() {
    bool mapFilterActive = _selectedPredefinedFilter == 'Map';
    final theme = Theme.of(context); // Get theme
    final colorScheme = theme.colorScheme; 
    final isDark = theme.brightness == Brightness.dark;
    final inputDecorationTheme = theme.inputDecorationTheme;

    // Define colors based on theme and map state
    Color fillColor =
        mapFilterActive
            ? (isDark
                ? Colors.grey.shade800.withOpacity(0.5)
                : Colors.grey.shade100) 
            : inputDecorationTheme.fillColor ??
                colorScheme.surface; 
    Color hintColor =
        mapFilterActive
            ? theme.disabledColor
            : inputDecorationTheme.hintStyle?.color ?? theme.hintColor;
    Color iconColor =
        mapFilterActive
            ? theme.disabledColor
            : inputDecorationTheme.prefixIconColor ??
                theme.iconTheme.color ??
                colorScheme.onSurfaceVariant;
    Color clearIconColor = theme.hintColor; 
    Color dividerColor = theme.dividerColor;
    Color filterIconColor =
        mapFilterActive
            ? theme.disabledColor
            : _selectedSpecialtyFilter == null
            ? (inputDecorationTheme.suffixIconColor ??
                theme.iconTheme.color ??
                colorScheme.onSurfaceVariant)
            : colorScheme.primary; // Use primary color when filter active

    return TextField(
      controller: _searchController,
      enabled: !mapFilterActive,
      style: TextStyle(
        color: mapFilterActive ? theme.disabledColor : null,
      ), // Dim text if map active
      decoration: InputDecoration(
        filled: inputDecorationTheme.filled ?? true,
        fillColor: fillColor, 
        contentPadding:
            inputDecorationTheme.contentPadding ??
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
        hintText:
            mapFilterActive
                ? 'Map View Active'
                : 'Search Doctor or Specialty...',
        hintStyle:
            inputDecorationTheme.hintStyle?.copyWith(color: hintColor) ??
            TextStyle(color: hintColor, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 15, right: 10),
          child: Icon(Icons.search, size: 22, color: iconColor),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clear button
            if (_searchController.text.isNotEmpty && !mapFilterActive)
              IconButton(
                icon: Icon(Icons.clear, color: clearIconColor, size: 20),
                tooltip: 'Clear Search',
                onPressed: () {
                  _searchController.clear();
                },
                splashRadius: 20,
                padding: EdgeInsets.zero,
              )
            else
              const SizedBox(width: 48), 
            // Divider
            SizedBox(
              height: 30,
              child: VerticalDivider(
                color: dividerColor,
                indent: 5,
                endIndent: 5,
                thickness: 0.7,
              ),
            ),
            // Specialty Filter Popup
            PopupMenuButton<String?>(
              icon: Icon(
                Icons.filter_list_outlined,
                size: 24,
                color: filterIconColor,
              ),
              tooltip: mapFilterActive ? null : 'Filter by Specialty',
              enabled: !mapFilterActive, // Disable popup when map active
              onSelected: mapFilterActive ? null : _onSpecialtyFilterSelected,
              itemBuilder:
                  mapFilterActive
                      ? (BuildContext context) =>
                          <PopupMenuEntry<String?>>[] // No items if map active
                      : (BuildContext context) {
                        // Use theme for text style in popup
                        final popupTextStyle = theme.textTheme.bodyLarge;
                        final boldPopupTextStyle = popupTextStyle?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        );

                        Set<String> specialties = _getUniqueSpecialties();
                        List<PopupMenuEntry<String?>> menuItems = [];
                        menuItems.add(
                          PopupMenuItem<String?>(
                            value: null, // Represents 'All Specialties'
                            child: Text(
                              'All Specialties',
                              style:
                                  _selectedSpecialtyFilter == null
                                      ? boldPopupTextStyle
                                      : popupTextStyle,
                            ),
                          ),
                        );
                        if (specialties.isNotEmpty) {
                          menuItems.add(const PopupMenuDivider());
                        }
                        var sortedSpecialties = specialties.toList()..sort();
                        for (String specialty in sortedSpecialties) {
                          menuItems.add(
                            PopupMenuItem<String?>(
                              value: specialty,
                              child: Text(
                                specialty,
                                style:
                                    _selectedSpecialtyFilter == specialty
                                        ? boldPopupTextStyle
                                        : popupTextStyle,
                              ),
                            ),
                          );
                        }
                        return menuItems;
                      },
            ),
            const SizedBox(width: 8),
          ],
        ),
        // Use theme borders
        border:
            inputDecorationTheme.border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.5),
              ),
            ),
        enabledBorder:
            inputDecorationTheme.enabledBorder ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.5),
              ),
            ),
        focusedBorder:
            inputDecorationTheme.focusedBorder ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
        disabledBorder:
            inputDecorationTheme.disabledBorder ??
            OutlineInputBorder(
              // Style when disabled (map active)
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doctor Appointment',
        ), 
        centerTitle: true,
        actions: [
          if (!_isGuest && _loggedInUserId != null)
            IconButton(
              icon: const Icon(
                Icons.logout_outlined,
              ), 
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
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        showUnselectedLabels: true, 
        onTap: _onItemTapped,
      ),
    );
  }
}
