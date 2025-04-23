// lib/screens/Home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // temporarily removed map import
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/doctor.dart';
import '/widgets/doctor_list_item.dart';
import 'InitLogin.dart';
import 'Appointments.dart';
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

  // Key for local appointment storage 
  static const String _prefsKeyAppointments = 'user_appointments_cache';

  // --- Search & Filter State ---
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _filteredDoctors = [];
  String? _selectedSpecialtyFilter;
  String? _selectedPredefinedFilter;
  final List<String> _predefinedFilters = [
    'All',
    'Favorites',
    'Dermatology',
    'Cardiology',
    'Pediatrics', 
    // Add other relevant specialties based on your data
  ];

  // --- Firestore Doctor Data State ---
  List<Doctor> _doctors = [];
  List<Doctor> _favoriteDoctors = [];
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;
  Set<String> _userFavoriteIds =
      {}; // User's favorite doctor IDs from Firestore
  final Set<String> _togglingFavorite = {}; // Tracks ongoing favorite toggles

  @override
  void initState() {
    super.initState();
    _selectedPredefinedFilter = _predefinedFilters.first; // Default to 'All'
    _initializeHome();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // --- Initialization and User Status ---
  Future<void> _initializeHome() async {
    await _loadUserStatus(); // Load user status first
    if (mounted) {
      _showWelcomeSnackBar();
      // Fetch doctors only if logged in or guest mode allows viewing
      if (_loggedInUserId != null || _isGuest) {
        await _fetchDoctors();
      } else {
        // Handle case where user needs to log in
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
        message,
        textAlign: TextAlign.center,
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
    return _doctors.map((doctor) => doctor.specialty).toSet();
  }

  void _onSearchChanged() {
    _filterDoctors();
  }

  void _onPredefinedFilterSelected(String filter) {
    setState(() {
      _selectedPredefinedFilter = filter;
      _selectedSpecialtyFilter =
          null; // Reset dropdown when predefined is chosen
    });
    _filterDoctors();
  }

  void _onSpecialtyFilterSelected(String? specialty) {
    setState(() {
      _selectedSpecialtyFilter = specialty;
      // Reset predefined filter ONLY if the selected specialty is not null
      // If user selects 'All Specialties' (null), keep the predefined filter active
      if (specialty != null) {
        _selectedPredefinedFilter = 'All';
      }
    });
    _filterDoctors();
  }

  // Applies filters based on current state
  void _filterDoctors() {
    if (!mounted) return;

    final lowerCaseQuery = _searchController.text.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(
      _doctors,
    ); // Start with the master list

    // 1. Apply Predefined Filter
    if (_selectedPredefinedFilter != null &&
        _selectedPredefinedFilter != 'All') {
      if (_selectedPredefinedFilter == 'Favorites') {
        // Filter by the isFavorite flag
        tempFilteredList =
            tempFilteredList.where((doctor) => doctor.isFavorite).toList();
      } else {
        // Filter by specialty
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

    // 2. Apply Dropdown Specialty Filter (Only if 'Favorites' button is NOT active)
    if (_selectedSpecialtyFilter != null &&
        _selectedPredefinedFilter != 'Favorites') {
      tempFilteredList =
          tempFilteredList
              .where((doctor) => doctor.specialty == _selectedSpecialtyFilter)
              .toList();
    }

    // 3. Apply Text Search Filter (applied last)
    if (lowerCaseQuery.isNotEmpty) {
      tempFilteredList =
          tempFilteredList.where((doctor) {
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

  // --- Data Fetching  ---
  Future<void> _fetchDoctors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDoctors = true;
      _errorLoadingDoctors = null;
      _doctors = [];
      _filteredDoctors = [];
      _favoriteDoctors = [];
      _userFavoriteIds = {};
    });

    try {
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
              _userFavoriteIds =
                  List<String>.from(data['favoriteDoctorIds']).toSet();
            }
          }
        } catch (e) {
          print("Error fetching user favorites: $e");
        }
      }

      QuerySnapshot doctorSnapshot =
          await FirebaseFirestore.instance.collection('doctors').get();

      if (mounted) {
        final List<Doctor> processedDoctors =
            doctorSnapshot.docs.map((doc) {
              Doctor doctor = Doctor.fromFirestore(doc);
              bool isFav = _userFavoriteIds.contains(doctor.id);
              return Doctor(
                id: doctor.id,
                name: doctor.name,
                specialty: doctor.specialty,
                address: doctor.address,
                phone: doctor.phone,
                imageUrl: doctor.imageUrl,
                rating: doctor.rating,
                location: doctor.location,
                bio: doctor.bio, //workingHours: doctor.workingHours,
                isFavorite: isFav,
              );
            }).toList();

        setState(() {
          _doctors = processedDoctors;
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList();
          _isLoadingDoctors = false;
          _errorLoadingDoctors = null;
          _filterDoctors();
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
          _doctors = [];
          _filteredDoctors = [];
          _favoriteDoctors = [];
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
        currentIsFavorite
            ? _userFavoriteIds.remove(doctorId)
            : _userFavoriteIds.add(doctorId);
        List<Doctor> updatedDoctors =
            _doctors.map((doctor) {
              if (doctor.id == doctorId) {
                return Doctor(
                  id: doctor.id,
                  name: doctor.name,
                  specialty: doctor.specialty,
                  address: doctor.address,
                  phone: doctor.phone,
                  imageUrl: doctor.imageUrl,
                  rating: doctor.rating,
                  location: doctor.location,
                  bio: doctor.bio, // workingHours: doctor.workingHours,
                  isFavorite: !currentIsFavorite,
                );
              }
              return doctor;
            }).toList();
        setState(() {
          _doctors = updatedDoctors;
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList();
          _filterDoctors();
        });
      }
    } catch (e) {
      print("Error toggling favorite: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update favorites: ${e.toString()}'),
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
    {
      // Show confirmation dialog and handle logout process
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
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: const Text('Logout'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          ) ??
          false; // Default to false if dialog is dismissed

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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const InitLogin()),
          (Route<dynamic> route) => false,
        );
      }
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
        return _homeScreenBody();
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
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const InitLogin()),
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the main content for the Home tab
  Widget _homeScreenBody() {
    return Column(
      children: [
        // Search Section
        Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 10.0,
            bottom: 5.0,
          ),
          child: _searchSection(),
        ),
        // Scrollable Content Area
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDoctors,
            child: CustomScrollView(
              slivers: <Widget>[
                // Predefined Filters
                SliverToBoxAdapter(child: _buildPredefinedFilters()),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Main Doctor List (Handles all display including favorites via filter)
                _buildSliverDoctorList(),
                // Bottom Padding
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDoctorListTitle() {
    bool isAnyFilterActive =
        _searchController.text.isNotEmpty ||
        _selectedSpecialtyFilter != null ||
        (_selectedPredefinedFilter != null &&
            _selectedPredefinedFilter != 'All');
    if (_selectedPredefinedFilter == 'Favorites') {
      return 'Favorite Doctors';
    }
    return isAnyFilterActive ? 'Filtered Doctors' : 'Available Doctors';
  }

  // --- Build Main Doctor List as Sliver ---
  Widget _buildSliverDoctorList() {
    if (_isLoadingDoctors && _doctors.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorLoadingDoctors != null && _doctors.isEmpty) {
      return SliverFillRemaining(child: _buildErrorWidget());
    }
    if (_filteredDoctors.isEmpty) {
      if (_selectedPredefinedFilter == 'Favorites' && !_isGuest) {
        return SliverToBoxAdapter(child: _buildEmptyFavoritesMessage());
      }
      return SliverToBoxAdapter(child: _buildEmptyListWidget());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final doctor = _filteredDoctors[index];
        return DoctorListItem(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListWidget() {
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
              if (selected) {
                _onPredefinedFilterSelected(filter);
              }
            },
            showCheckmark: false,
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.9),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color:
                  isSelected
                      ? Colors.white
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
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 15.0,
        ),
        hintText: 'Search Doctor or Specialty...',
        hintStyle: const TextStyle(color: Color(0xffDDDADA), fontSize: 14),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 15, right: 10),
          child: Icon(Icons.search, size: 22),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                tooltip: 'Clear Search',
                onPressed: () {
                  _searchController.clear();
                },
              ),
            const SizedBox(
              height: 30,
              child: VerticalDivider(
                color: Colors.grey,
                indent: 5,
                endIndent: 5,
                thickness: 0.7,
              ),
            ),
            PopupMenuButton<String?>(
              icon: Icon(
                Icons.filter_list,
                size: 24,
                color:
                    _selectedSpecialtyFilter == null
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
              ),
              tooltip: 'Filter by Specialty',
              onSelected: _onSpecialtyFilterSelected,
              itemBuilder: (BuildContext context) {
                Set<String> specialties = _getUniqueSpecialties();
                List<PopupMenuEntry<String?>> menuItems = [];
                menuItems.add(
                  PopupMenuItem<String?>(
                    value: null,
                    child: Text(
                      'All Specialties',
                      style: TextStyle(
                        fontWeight:
                            _selectedSpecialtyFilter == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
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
                        style: TextStyle(
                          fontWeight:
                              _selectedSpecialtyFilter == specialty
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
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
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // --- Main Build Method for the entire screen ---
  @override // <--- This build method MUST be INSIDE _HomeState
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
      body: _buildBody(), // Calls a method within _HomeState
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
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        onTap: _onItemTapped, // Calls a method within _HomeState
      ),
    );
  } // <--- End of build method
}
