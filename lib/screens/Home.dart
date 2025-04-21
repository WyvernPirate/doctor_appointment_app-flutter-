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

  // --- Search & Filter State ---
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _filteredDoctors = [];
  String? _selectedSpecialtyFilter;
  String? _selectedPredefinedFilter;
  final List<String> _predefinedFilters = [
    'All', 'Cardiology', 'Dental', 'Consultant', 'Skin', 'Pediatrics',
  ];

  // --- Firestore Doctor Data State ---
  List<Doctor> _doctors = [];
  List<Doctor> _favoriteDoctors = [];
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;

  @override
  void initState() {
    super.initState();
    _selectedPredefinedFilter = _predefinedFilters.first;
    _initializeHome();
    _fetchDoctors();
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
    await _loadUserStatus();
    if (mounted) {
      _showWelcomeSnackBar();
    }
  }

  Future<void> _loadUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGuest = prefs.getBool('isGuest') ?? false;
      _loggedInUserId = prefs.getString('loggedInUserId');
    });
  }

  // Function to show the welcome SnackBar
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
       // Reset dropdown filter when a predefined one is chosen (optional)
       _selectedSpecialtyFilter = null;
     });
     _filterDoctors();
  }

  void _onSpecialtyFilterSelected(String? specialty) {
     setState(() {
       _selectedSpecialtyFilter = specialty;
       // Reset predefined filter when dropdown is used (optional)
       _selectedPredefinedFilter = 'All';
     });
     _filterDoctors();
  }

  void _filterDoctors() {
    if (!mounted) return;
    final lowerCaseQuery = _searchController.text.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(_doctors);

    // Apply Predefined Filter
    if (_selectedPredefinedFilter != null && _selectedPredefinedFilter != 'All') {
      tempFilteredList = tempFilteredList.where((doctor) =>
          doctor.specialty.toLowerCase() == _selectedPredefinedFilter!.toLowerCase()).toList();
    }

    // Apply Dropdown Specialty Filter
    if (_selectedSpecialtyFilter != null) {
      tempFilteredList = tempFilteredList.where((doctor) =>
          doctor.specialty == _selectedSpecialtyFilter).toList();
    }

    // Apply Text Search Filter
    if (lowerCaseQuery.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((doctor) {
        final lowerCaseName = doctor.name.toLowerCase();
        final lowerCaseSpecialty = doctor.specialty.toLowerCase();
        return lowerCaseName.contains(lowerCaseQuery) ||
               lowerCaseSpecialty.contains(lowerCaseQuery);
      }).toList();
    }

    setState(() {
      _filteredDoctors = tempFilteredList;
    });
  }

  // --- Data Fetching ---
  Future<void> _fetchDoctors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDoctors = true;
      _errorLoadingDoctors = null;
      // Don't clear filters on refresh, just data
      _doctors = [];
      _filteredDoctors = [];
      _favoriteDoctors = [];
    });
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('doctors').get();
      if (mounted) {
        final fetchedDoctors = querySnapshot.docs
            .map((doc) => Doctor.fromFirestore(doc))
            .toList();
        setState(() {
          _doctors = fetchedDoctors;
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList();
          _isLoadingDoctors = false;
          _filterDoctors(); // Apply existing filters to new data
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
          _doctors = [];
          _filteredDoctors = [];
          _favoriteDoctors = [];
        });
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
        false;

    if (confirmLogout) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
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

  // --- Removed Map Method ---
  // void _onMapCreated(GoogleMapController controller) { ... }

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
        return _isGuest ? _guestModeNotice("view appointments") : const Appointments();
      case 2:
        return _isGuest ? _guestModeNotice("view your profile") : const Profile();
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
            )
          ],
        ),
      ),
    );
  }

  Widget _homeScreenBody() {
    return RefreshIndicator(
      onRefresh: _fetchDoctors, // Pull down to refresh works
      child: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            title: const Text('Doctor Appointment'), 
            centerTitle: true, 
            backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Match background
            elevation: 1, 
            pinned: true,  
            floating: true, 
            snap: false,   
            actions: [ // <-- ADDED ACTIONS
              if (!_isGuest && _loggedInUserId != null)
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: _handleLogout,
                ),
              const SizedBox(width: 8), // Padding for the action button
            ],
            // Flexible space holds the search bar below the title/actions
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                // Adjust top padding to place search below title/actions area
                padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top + 10, bottom: 10),
                child: _searchSection(),
              ),
            ),
            // Adjust height to fit title/actions + search bar + padding
            expandedHeight: kToolbarHeight + 80.0, // kToolbarHeight is standard AppBar height
          ),

          // --- Predefined Filters (Sliver) ---
          SliverToBoxAdapter(
            child: _buildPredefinedFilters(),
          ),

          // --- Header for Doctor List (Sliver) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 15, left: 16, right: 16, bottom: 10),
              child: Text( 
                _getDoctorListTitle(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // --- Main Doctor List (SliverList) ---
          _buildSliverDoctorList(),

          // --- Header for Favorites (Sliver) ---
          if (!_isGuest && _favoriteDoctors.isNotEmpty)
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.only(top: 25, left: 16, right: 16, bottom: 10),
                 child: Text(
                   'Your Favorite Doctors',
                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                 ),
               ),
             ),

          // --- Favorite Doctor List (SliverList) ---
          if (!_isGuest)
             _buildSliverFavoriteDoctorList(),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  String _getDoctorListTitle() {
     if (_searchController.text.isNotEmpty || _selectedSpecialtyFilter != null || (_selectedPredefinedFilter != null && _selectedPredefinedFilter != 'All')) {
       return 'Filtered Doctors';
     }
     return 'Available Doctors';
  }

  // --- Build Main Doctor List as Sliver ---
  Widget _buildSliverDoctorList() {
    if (_isLoadingDoctors) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }
    if (_errorLoadingDoctors != null) {
      return SliverFillRemaining(child: _buildErrorWidget());
    }
    if (_filteredDoctors.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyListWidget()); 
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => DoctorListItem(doctor: _filteredDoctors[index], isFavoriteView: false),
        childCount: _filteredDoctors.length,
      ),
    );
  }

   // --- Build Favorite Doctor List as Sliver ---
  Widget _buildSliverFavoriteDoctorList() {
    if (_isLoadingDoctors) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (_favoriteDoctors.isEmpty && !_isGuest) {
       return SliverToBoxAdapter(child: _buildEmptyFavoritesWidget()); 
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => DoctorListItem(doctor: _favoriteDoctors[index], isFavoriteView: true),
        childCount: _favoriteDoctors.length,
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
              _errorLoadingDoctors!,
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
          _doctors.isEmpty ? 'No doctors found at the moment.' : 'No doctors match your current filters.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

   Widget _buildEmptyFavoritesWidget() {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
       child: Center(
         child: Text(
           'You haven\'t added any favorite doctors yet.',
           textAlign: TextAlign.center,
           style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
         ),
       ),
     );
   }

  // Predefined Filter Buttons
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
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
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

  // --- Search Section
  Widget _searchSection() {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0),
       child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
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
                  onPressed: () { _searchController.clear(); },
                ),
              const SizedBox(
                 height: 30,
                 child: VerticalDivider(color: Colors.grey, indent: 5, endIndent: 5, thickness: 0.7),
              ),
              PopupMenuButton<String?>(
                icon: Icon(
                  Icons.filter_list,
                  size: 24,
                  color: _selectedSpecialtyFilter == null ? Colors.grey : Theme.of(context).primaryColor,
                ),
                tooltip: 'Filter by Specialty',
                onSelected: _onSpecialtyFilterSelected,
                itemBuilder: (BuildContext context) {
                  Set<String> specialties = _getUniqueSpecialties();
                  List<PopupMenuEntry<String?>> menuItems = [];
                  menuItems.add(
                    PopupMenuItem<String?>(
                      value: null,
                      child: Text('All Specialties', style: TextStyle(fontWeight: _selectedSpecialtyFilter == null ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                  if (specialties.isNotEmpty) {
                     menuItems.add(const PopupMenuDivider());
                  }
                  // Create sorted list for consistent order
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
        ),
      ),
    );
  }

  // --- Main Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(

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