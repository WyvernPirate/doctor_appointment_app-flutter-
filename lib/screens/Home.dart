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
  
  static const String _prefsKeyAppointments = 'user_appointments_cache';

  // --- Search & Filter State ---
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _filteredDoctors = [];
  String? _selectedSpecialtyFilter;
  String? _selectedPredefinedFilter;
  final List<String> _predefinedFilters = [
    'All', 'Cardiology', 'Dermatology', 'Favorites', 'Cardiology', 'Pediatrics',
  ];

  // --- Firestore Doctor Data State ---
  List<Doctor> _doctors = [];
  List<Doctor> _favoriteDoctors = [];
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;

  @override
  void initState() {
    super.initState();
    _selectedPredefinedFilter = _predefinedFilters.first; // Default to 'All'
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
    // Get unique specialties from the main doctor list
    return _doctors.map((doctor) => doctor.specialty).toSet();
  }

  void _onSearchChanged() {
    // Trigger filtering when search text changes
    _filterDoctors();
  }

  void _onPredefinedFilterSelected(String filter) {
     // Update state when a predefined filter button is tapped
     setState(() {
       _selectedPredefinedFilter = filter;
       _selectedSpecialtyFilter = null;
     });
     _filterDoctors();
  }

  void _onSpecialtyFilterSelected(String? specialty) {
     // Update state when a specialty is selected from the dropdown
     setState(() {
       _selectedSpecialtyFilter = specialty;     
       _selectedPredefinedFilter = 'All';
     });
     _filterDoctors();
  }

  void _filterDoctors() {
    // Main filtering logic based on current state
    if (!mounted) return;

    final lowerCaseQuery = _searchController.text.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(_doctors); // Start with all doctors

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
        // Add more fields to search here if needed
        return lowerCaseName.contains(lowerCaseQuery) ||
               lowerCaseSpecialty.contains(lowerCaseQuery);
      }).toList();
    }

    // Update the state with the final filtered list
    setState(() {
      _filteredDoctors = tempFilteredList;
    });
  }

  // --- Data Fetching ---
  Future<void> _fetchDoctors() async {
    // Fetch doctors from Firestore and update state
    if (!mounted) return;
    setState(() {
      _isLoadingDoctors = true;
      _errorLoadingDoctors = null;
      // Don't clear filters on refresh, just clear data lists
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
          // Populate favorites based on the isFavorite flag from Firestore data
          _favoriteDoctors = _doctors.where((d) => d.isFavorite).toList();
          _isLoadingDoctors = false;
          _filterDoctors(); // Apply current filters to the newly fetched data
        });
      }
    } catch (e, stackTrace) {
      print("Error fetching doctors: $e\n$stackTrace");
      if (mounted) {
        // Handle errors during fetching
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
    // Show confirmation dialog and handle logout process
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
    ) ?? false; // Default to false if dialog is dismissed

    if (confirmLogout) {
      // Clear user session data
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('loggedInUserId');
      await prefs.remove('loggedInUserId');
      await prefs.setBool('isGuest', false); // Reset guest status

      if (userId != null) {
         await prefs.remove(_prefsKeyAppointments + userId); // Remove user-specific cache
         print("Local appointments cache cleared for user $userId.");
      }

      if (!mounted) return;
      // Navigate to login screen and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const InitLogin()),
        (Route<dynamic> route) => false,
      );
    }
  }

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

  // Widget to display when user is in guest mode for restricted sections
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
                // Navigate to login screen
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

  // Builds the main content for the Home tab 
  Widget _homeScreenBody() {
    return Column(
      children: [
        // --- Search Section ---
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 5.0),
          child: _searchSection(), 
        ),

        // --- Scrollable Content Area ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDoctors, 
            child: CustomScrollView(
              slivers: <Widget>[
                // --- Predefined Filter Buttons ---
                SliverToBoxAdapter(
                  child: _buildPredefinedFilters(),
                ),

                // --- Header for the Main Doctor List ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15, left: 16, right: 16, bottom: 10),
                    child: Text(
                      _getDoctorListTitle(), // Dynamic title based on filters
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // --- Main Doctor List  ---
                _buildSliverDoctorList(),

                // --- Header for Favorite Doctors Section ---
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

                // --- Favorite Doctor List ---
                // Show only if logged in
                if (!_isGuest)
                   _buildSliverFavoriteDoctorList(),

                // Add some padding at the very bottom of the scroll view
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper to get the title for the main doctor list based on filter state
  String _getDoctorListTitle() {
     bool isAnyFilterActive = _searchController.text.isNotEmpty ||
                              _selectedSpecialtyFilter != null ||
                              (_selectedPredefinedFilter != null && _selectedPredefinedFilter != 'All');
     return isAnyFilterActive ? 'Filtered Doctors' : 'Available Doctors';
  }

  // --- Build Main Doctor List as Sliver ---
  Widget _buildSliverDoctorList() {
    // Handle loading state
    if (_isLoadingDoctors) {
      // Show a loading indicator centered within the remaining space
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Handle error state
    if (_errorLoadingDoctors != null) {
      // Show error message and retry button centered within the remaining space
      return SliverFillRemaining(
        child: _buildErrorWidget(),
      );
    }
    if (_filteredDoctors.isEmpty) {
      // Show an empty list message
      return SliverToBoxAdapter( 
        child: _buildEmptyListWidget(),
      );
    }
    // Build the actual list using SliverList
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Build each doctor item using the DoctorListItem widget
          return DoctorListItem(doctor: _filteredDoctors[index], isFavoriteView: false);
        },
        childCount: _filteredDoctors.length, 
      ),
    );
  }

   // --- Build Favorite Doctor List as Sliver ---
  Widget _buildSliverFavoriteDoctorList() {
    // Loading/Error is handled by the main list's state for simplicity
    if (_isLoadingDoctors) {
      // Don't show anything for favorites while the main list is loading
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    // Handle empty favorites list state (only if logged in)
    if (_favoriteDoctors.isEmpty && !_isGuest) {
       // Show a message indicating no favorites have been added
       return SliverToBoxAdapter(
         child: _buildEmptyFavoritesWidget(),
       );
    }
    // Build the list of favorite doctors using SliverList
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Build each favorite doctor item, potentially styled differently
          return DoctorListItem(doctor: _favoriteDoctors[index], isFavoriteView: true);
        },
        childCount: _favoriteDoctors.length, // Number of favorite doctors
      ),
    );
  }

  // --- Helper Widgets for List States ---
  // Builds the widget shown when there's an error fetching doctors
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
              _errorLoadingDoctors!, // Display the error message
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700], fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _fetchDoctors, // Allow user to retry fetching
            ),
          ],
        ),
      ),
    );
  }

  // Builds the widget shown when the main doctor list is empty (either initially or after filtering)
  Widget _buildEmptyListWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
        child: Text(
          // Provide context-specific message
          _doctors.isEmpty
              ? 'No doctors found at the moment.' // If the original list was empty
              : 'No doctors match your current filters.', // If filters resulted in empty list
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  // Builds the widget shown when the favorite doctors list is empty
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

  // Builds the horizontal list of predefined filter chips
  Widget _buildPredefinedFilters() {
     return Container(
      height: 50, // Fixed height for the filter bar
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal, // Make it scroll horizontally
        itemCount: _predefinedFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8), // Space between chips
        itemBuilder: (context, index) {
          final filter = _predefinedFilters[index];
          final isSelected = filter == _selectedPredefinedFilter; // Check if this chip is selected

          // Use FilterChip for selectable category buttons
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              // Only trigger update if the chip is being selected
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
     // Use padding here if needed, or rely on padding applied in _homeScreenBody
    
     return TextField(
        controller: _searchController,
        decoration: InputDecoration(
          filled: true, // Use a fill color
          fillColor: Colors.white, // Background color of the field
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0), // Inner padding
          hintText: 'Search Doctor or Specialty...', // Placeholder text
          hintStyle: const TextStyle(color: Color(0xffDDDADA), fontSize: 14), // Style for hint text
          // Search icon at the beginning
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 15, right: 10),
            child: Icon(Icons.search, size: 22),
          ),
          // Icons at the end (clear button and filter dropdown)
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min, // Take only needed horizontal space
            children: [
              // Show clear button only if there is text in the search field
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                  tooltip: 'Clear Search',
                  onPressed: () {
                    _searchController.clear(); // Clear text, listener will trigger filter update
                  },
                ),
              // Optional visual divider
              const SizedBox(
                 height: 30, // Adjust height to match input field
                 child: VerticalDivider(color: Colors.grey, indent: 5, endIndent: 5, thickness: 0.7),
              ),
              // Dropdown menu button for specialty filtering
              PopupMenuButton<String?>(
                icon: Icon(
                  Icons.filter_list,
                  size: 24,
                  // Change icon color if a specialty filter is active
                  color: _selectedSpecialtyFilter == null ? Colors.grey : Theme.of(context).primaryColor,
                ),
                tooltip: 'Filter by Specialty',
                onSelected: _onSpecialtyFilterSelected, // Callback when an item is selected
                itemBuilder: (BuildContext context) {
                  // Build the dropdown menu items
                  Set<String> specialties = _getUniqueSpecialties();
                  List<PopupMenuEntry<String?>> menuItems = [];

                  // Add "All Specialties" option
                  menuItems.add(
                    PopupMenuItem<String?>(
                      value: null, // Use null to represent 'All'
                      child: Text(
                        'All Specialties',
                        style: TextStyle(fontWeight: _selectedSpecialtyFilter == null ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  );

                  // Add divider if there are specific specialties
                  if (specialties.isNotEmpty) {
                     menuItems.add(const PopupMenuDivider());
                  }

                  // Create a sorted list of specialties for consistent order
                  var sortedSpecialties = specialties.toList()..sort();
                  // Add menu item for each unique specialty
                  for (String specialty in sortedSpecialties) {
                    menuItems.add(
                      PopupMenuItem<String?>(
                        value: specialty,
                        child: Text(
                          specialty,
                          style: TextStyle(fontWeight: _selectedSpecialtyFilter == specialty ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                    );
                  }
                  return menuItems;
                },
              ),
              const SizedBox(width: 8), // Padding after the filter icon
            ],
          ),
          // Define the border appearance
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), // Rounded corners
            borderSide: BorderSide(color: Colors.grey.shade300), // Default border
          ),
           enabledBorder: OutlineInputBorder( // Border when the field is enabled but not focused
             borderRadius: BorderRadius.circular(30),
             borderSide: BorderSide(color: Colors.grey.shade300),
           ),
           focusedBorder: OutlineInputBorder( // Border when the field is focused
             borderRadius: BorderRadius.circular(30),
             borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5), // Highlight border
           ),
        ),
      );
  }

  // --- Main Build Method for the entire screen ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Doctor Appointment'),
        centerTitle: true,
        elevation: 1, // Subtle shadow below AppBar
        actions: [
          // Show logout button only if user is logged in
          if (!_isGuest && _loggedInUserId != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _handleLogout, // Trigger logout process
            ),
          const SizedBox(width: 8), // Padding for the action button
        ],
      ),
     
      body: _buildBody(),
      // Bottom navigation bar
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