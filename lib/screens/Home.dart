// lib/screens/Home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

// Models and Widgets
import '/models/doctor.dart';
import '/widgets/home/home_search_section.dart'; 
import '/widgets/home/home_filter_chips.dart';   
import '/widgets/home/home_map_view.dart';       
import '/widgets/home/home_doctor_list_view.dart';

// Screens
import 'Appointments.dart';
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
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;
  Set<String> _userFavoriteIds = {};
  final Set<String> _togglingFavorite = {};

  // --- Location and Map State ---
  Position? _currentUserPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  String? _lightMapStyle;
  String? _darkMapStyle;
 

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
    super.dispose();
  }

  // --- Load both map styles ---
  Future<void> _loadMapStyles() async {
    try {
      final lightStyle = await rootBundle.loadString('lib/assets/map_style.json');
      final darkStyle = await rootBundle.loadString('lib/assets/map_style_dark.json');
      if (mounted) {
        setState(() {
          _lightMapStyle = lightStyle;
          _darkMapStyle = darkStyle;
        });
      }
    } catch (e) {
      print("Error loading map styles: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
          color: _isGuest ? Colors.black87 : theme.colorScheme.onPrimary,
        ),
      ),
      duration: const Duration(seconds: 3),
      backgroundColor: _isGuest ? Colors.orangeAccent : theme.colorScheme.primary,
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
    bool switchingFromMap = _selectedPredefinedFilter == 'Map' && filter != 'Map';

    setState(() {
      _selectedPredefinedFilter = filter;
      // Reset specialty dropdown if switching away from map or selecting a predefined specialty
      if (switchingFromMap || (filter != 'Map' && filter != 'Favorites' && filter != 'All')) {
        _selectedSpecialtyFilter = null;
      }
      // Clear search only when selecting a predefined *specialty* chip
      if (filter != 'Map' && filter != 'Favorites' && filter != 'All') {
        _searchController.clear(); 
      }
       // Clear location error when switching away from map
      if (switchingFromMap) {
        _locationError = null;
        _isLoadingLocation = false; // Ensure loading indicator stops
      }
    });

    if (switchingToMap) {
      // Fetch location when map is selected
      _getCurrentLocation();
      // Clear list filters when switching to map (already handled by filter logic)
      setState(() {
        _filteredDoctors = []; // Explicitly clear for map view
      });
    } else {
      _filterDoctors(); // Apply list filters
    }
  }

  void _onSpecialtyFilterSelected(String? specialty) {
    if (_selectedPredefinedFilter == 'Map') return;
    setState(() {
      _selectedSpecialtyFilter = specialty;
      // If a specialty is chosen via dropdown, ensure the 'All' chip is active (unless 'Favorites' is active)
      if (specialty != null && _selectedPredefinedFilter != 'Favorites') {
        _selectedPredefinedFilter = 'All';
      }
    });
    _filterDoctors();
  }

  // --- List Filtering Logic (Remains the same) ---
  void _filterDoctors() {
    if (!mounted || _selectedPredefinedFilter == 'Map') {
       // If map is selected, ensure the list is empty
       if (_selectedPredefinedFilter == 'Map' && _filteredDoctors.isNotEmpty) {
           setState(() {
               _filteredDoctors = [];
           });
       }
       return;
    }

    final lowerCaseQuery = _searchController.text.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(_doctors); // Start with the master list

    // Apply Predefined Filter Chip (excluding 'Map', 'All')
    if (_selectedPredefinedFilter != null && _selectedPredefinedFilter != 'All' && _selectedPredefinedFilter != 'Map') {
      if (_selectedPredefinedFilter == 'Favorites') {
        tempFilteredList = tempFilteredList.where((doctor) => _userFavoriteIds.contains(doctor.id)).toList(); // Use updated _userFavoriteIds
      } else {
        // Filter by specialty chip
        tempFilteredList = tempFilteredList.where((doctor) => doctor.specialty.toLowerCase() == _selectedPredefinedFilter!.toLowerCase()).toList();
      }
    }

    // Apply Dropdown Specialty Filter (only if 'Favorites' chip is NOT selected)
    if (_selectedSpecialtyFilter != null && _selectedPredefinedFilter != 'Favorites') {
      tempFilteredList = tempFilteredList.where((doctor) => doctor.specialty == _selectedSpecialtyFilter).toList();
    }

    // Apply Text Search Filter (applied last)
    if (lowerCaseQuery.isNotEmpty) {
       // Apply search regardless of specialty filter, but respect 'Favorites' chip
       tempFilteredList = tempFilteredList.where((doctor) {
            final lowerCaseName = doctor.name.toLowerCase();
            final lowerCaseSpecialty = doctor.specialty.toLowerCase();
            return lowerCaseName.contains(lowerCaseQuery) || lowerCaseSpecialty.contains(lowerCaseQuery);
        }).toList();
    }

    // Update the state variable that the list view uses
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
      // Don't clear _filteredDoctors here, let filter logic handle it
      // _filteredDoctors = [];
      // _favoriteDoctors = []; // Keep for potential future use? Or remove if unused.
      // _userFavoriteIds = {}; // Fetch fresh below
    });

    List<Doctor> previouslyFetchedDoctors = List.from(_doctors); // Keep old data temporarily

    try {
      // 1. Fetch User's Favorite IDs (only if logged in)
      Set<String> fetchedFavoriteIds = {};
      if (_loggedInUserId != null) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_loggedInUserId!).get();
          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data() as Map<String, dynamic>;
            if (data.containsKey('favoriteDoctorIds') && data['favoriteDoctorIds'] is List) {
              fetchedFavoriteIds = List<String>.from(data['favoriteDoctorIds']).toSet();
            }
          }
        } catch (e) {
          print("Error fetching user favorites: $e");
          // Decide if this error should block loading doctors or just proceed without favorites
        }
      }

      // 2. Fetch All Doctors
      QuerySnapshot doctorSnapshot = await FirebaseFirestore.instance.collection('doctors').get();

      if (mounted) {
        // Process Doctors (No need to merge favorite status here, _userFavoriteIds handles it)
        final List<Doctor> processedDoctors = doctorSnapshot.docs.map((doc) {
          // Note: Doctor.fromFirestore should NOT set isFavorite.
          // isFavorite is now determined dynamically based on _userFavoriteIds.
          return Doctor.fromFirestore(doc);
        }).toList();

        // Update State
        setState(() {
          _doctors = processedDoctors; // Update the master list
          _userFavoriteIds = fetchedFavoriteIds; // Update the favorite IDs set
          _isLoadingDoctors = false;
          _errorLoadingDoctors = null;
          // Apply filters based on the current state
          _filterDoctors(); 
        });
      }
    } catch (e, stackTrace) {
      print("Error fetching doctors: $e\n$stackTrace");
      if (mounted) {
        String errorMessage = 'Failed to load doctors.';
        if (e is FirebaseException) {
          errorMessage += ' (Code: ${e.code})';
        } else if (e is FormatException || e is TypeError || e.toString().contains('toDouble')) {
          errorMessage = 'Error processing doctor data. Please check data format.';
          print("Data processing error likely related to Firestore data types.");
        } else {
          errorMessage += ' Please try again.';
        }
        setState(() {
          _errorLoadingDoctors = errorMessage;
          _isLoadingDoctors = false;
          _doctors = previouslyFetchedDoctors; // Revert to old data on error if available
          _filterDoctors();
        });
      }
    }
  }


  // --- Toggle Favorite Status ---
  Future<void> _toggleFavoriteStatus(String doctorId, bool currentIsFavorite ) async {
    if (_loggedInUserId == null || _togglingFavorite.contains(doctorId)) return;
    if (!mounted) return;

    // Determine the actual current favorite status from our state
    final bool isCurrentlyFavorite = _userFavoriteIds.contains(doctorId);

    setState(() {
      _togglingFavorite.add(doctorId);
    });

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(_loggedInUserId!);
    final updateData = isCurrentlyFavorite
        ? {'favoriteDoctorIds': FieldValue.arrayRemove([doctorId])}
        : {'favoriteDoctorIds': FieldValue.arrayUnion([doctorId])};

    try {
      await userDocRef.update(updateData);
      if (mounted) {
        // Update local state immediately for responsiveness
        setState(() {
          if (isCurrentlyFavorite) {
            _userFavoriteIds.remove(doctorId);
          } else {
            _userFavoriteIds.add(doctorId);
          }
        
          if (_selectedPredefinedFilter == 'Favorites') {
            _filterDoctors();
          }
           _togglingFavorite.remove(doctorId); // Remove here after successful state update
        });
      }
    } catch (e) {
      print("Error toggling favorite: $e");
      if (mounted) {
        
        setState(() {
          if (isCurrentlyFavorite) {
            _userFavoriteIds.add(doctorId); 
          } else {
            _userFavoriteIds.remove(doctorId); 
         }
          if (_selectedPredefinedFilter == 'Favorites') {
            _filterDoctors();
          }
         });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update favorites: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
         setState(() {
             _togglingFavorite.remove(doctorId); // Always remove from toggling state
         });
      }
    }
  }


  // --- Logout ( ---
  Future<void> _handleLogout() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    bool confirmLogout = await showDialog(
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
        ) ?? false;

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

  // --- Navigation  ---
  void _onItemTapped(int index) {
    // If switching away from map, clear location state
    if (_selectedIndex == 0 && _selectedPredefinedFilter == 'Map' && index != 0) {
       setState(() {
           _locationError = null;
           _isLoadingLocation = false;
       });
    }
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

  // Guest Mode Notice 
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

  // --- Builds the main content for the Home tab using extracted widgets ---
  Widget _homeScreenBody() {
    bool isMapSelected = _selectedPredefinedFilter == 'Map';

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
          // Use the extracted Search Section Widget
          child: HomeSearchSection(
            searchController: _searchController,
            mapFilterActive: isMapSelected,
            selectedSpecialtyFilter: _selectedSpecialtyFilter,
            uniqueSpecialties: _getUniqueSpecialties(),
            onSpecialtyFilterSelected: _onSpecialtyFilterSelected,
          ),
        ),
        // Use the extracted Filter Chips Widget
        HomeFilterChips(
          predefinedFilters: _predefinedFilters,
          selectedPredefinedFilter: _selectedPredefinedFilter,
          onFilterSelected: _onPredefinedFilterSelected,
        ),
        Expanded(
          child: isMapSelected
              // Use the extracted Map View Widget
              ? HomeMapView(
                  doctors: _doctors, // Pass all doctors for markers
                  currentUserPosition: _currentUserPosition,
                  isLoadingLocation: _isLoadingLocation,
                  locationError: _locationError,
                  onRetryLocation: _getCurrentLocation, // Pass retry callback
                  lightMapStyle: _lightMapStyle,
                  darkMapStyle: _darkMapStyle,
                )
              // Use the extracted List View Widget
              : HomeDoctorListView(
                  isLoadingDoctors: _isLoadingDoctors,
                  errorLoadingDoctors: _errorLoadingDoctors,
                  filteredDoctors: _filteredDoctors, // Pass the filtered list
                  allDoctors: _doctors, // Pass the master list for context
                  listTitle: _getDoctorListTitle(), // Pass the dynamic title
                  selectedPredefinedFilter: _selectedPredefinedFilter,
                  selectedSpecialtyFilter: _selectedSpecialtyFilter,
                  searchText: _searchController.text,
                  isGuest: _isGuest,
                  loggedInUserId: _loggedInUserId,
                  togglingFavoriteIds: _togglingFavorite,
                  onFavoriteToggle: _toggleFavoriteStatus, // Pass the toggle callback
                  onRefresh: _fetchDoctors, userFavoriteIds: _userFavoriteIds, // Pass the refresh callback
                ),
        ),
      ],
    );
  }

  // --- Get User Location  ---
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        setState(() {
          _currentUserPosition = position;
          _isLoadingLocation = false;
        });
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

  // --- Get Doctor List Title  ---
  String _getDoctorListTitle() {
    bool isSearchActive = _searchController.text.isNotEmpty;
    bool isSpecialtyFilterActive = _selectedSpecialtyFilter != null;
    bool isPredefinedSpecialtyActive = _selectedPredefinedFilter != null &&
        _selectedPredefinedFilter != 'All' &&
        _selectedPredefinedFilter != 'Map' &&
        _selectedPredefinedFilter != 'Favorites';

    if (_selectedPredefinedFilter == 'Favorites') {
      return 'Favorite Doctors';
    }
    // Combine filter conditions
    if (isSearchActive || isSpecialtyFilterActive || isPredefinedSpecialtyActive) {
      return 'Filtered Doctors';
    }
    return 'Available Doctors'; // Default title
  }


  // --- Main Build Method  ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Appointment'),
        centerTitle: true,
        actions: [
          if (!_isGuest && _loggedInUserId != null)
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Logout',
              onPressed: _handleLogout,
            ),
          const SizedBox(width: 8),
        ],
      ),

      // Body method
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
