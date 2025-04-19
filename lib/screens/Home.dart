// lib/screens/Home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

   // --- Search State ---
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _filteredDoctors = [];
  String? _selectedSpecialtyFilter;

  

  //Firestore Doctor Data State
  List<Doctor> _doctors = [];
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;

  late GoogleMapController mapController;
  final LatLng _gaboroneCenter = const LatLng(-24.6545, 25.9086);

  @override
  void initState() {
    super.initState();
    _initializeHome();
    _fetchDoctors();
  }

  // Helper function for async initialization
  Future<void> _initializeHome() async {
    await _loadUserStatus(); // Wait for user status
    if (mounted) {
      // Check if widget is still mounted before showing SnackBar
      _showWelcomeSnackBar(); // Show the welcome message
    }
  }

  // load the user status
  Future<void> _loadUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGuest = prefs.getBool('isGuest') ?? false;
      _loggedInUserId = prefs.getString('loggedInUserId');
    });
  }

  //Function to show the welcome SnackBar 
  void _showWelcomeSnackBar() {
    final message = _isGuest ? "Browsing as Guest" : "Welcome!";
    final snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      duration: const Duration(seconds: 3), // Adjust duration as needed
      backgroundColor: _isGuest ? Colors.orangeAccent : Colors.blueAccent,
      behavior: SnackBarBehavior.floating, // Makes it float above the BottomNavBar
      margin: const EdgeInsets.only(bottom: 70.0, left: 20.0, right: 20.0), // Adjust margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    );

    // Ensure Scaffold is available before showing SnackBar
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

 // --- Helper for Specialties ---
  Set<String> _getUniqueSpecialties() {
    // Use a Set to automatically handle uniqueness
    return _doctors.map((doctor) => doctor.specialty).toSet();
  }
  // --- Search Logic ---
  void _onSearchChanged() {
    _filterDoctors(_searchController.text);
  }

  void _filterDoctors(String query) {
    if (!mounted) return; // Ensure widget is still mounted

    final lowerCaseQuery = query.toLowerCase().trim();
    List<Doctor> tempFilteredList = List.from(_doctors); // Start with all doctors

    // 1. Apply Text Filter (if query exists)
    if (lowerCaseQuery.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((doctor) {
        final lowerCaseName = doctor.name.toLowerCase();
        final lowerCaseSpecialty = doctor.specialty.toLowerCase();
        return lowerCaseName.contains(lowerCaseQuery) ||
               lowerCaseSpecialty.contains(lowerCaseQuery);
      }).toList();
    }

    // 2. Apply Specialty Filter (if selected)
    if (_selectedSpecialtyFilter != null) {
      tempFilteredList = tempFilteredList.where((doctor) {
        return doctor.specialty == _selectedSpecialtyFilter;
      }).toList();
    }

    // Update the state with the final filtered list
    setState(() {
      _filteredDoctors = tempFilteredList;
    });
  }

  // fetch doctors from firebase
  Future<void> _fetchDoctors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDoctors = true;
      _errorLoadingDoctors = null;
    });
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('doctors').get();
      if (mounted) {
        setState(() {
          _doctors = querySnapshot.docs
              .map((doc) => Doctor.fromFirestore(doc))
              .toList();
          _isLoadingDoctors = false;
        });
      }
    } catch (e, stackTrace) {
      print("Error fetching doctors: $e");
      print(stackTrace); //stack trace for debugging
      if (mounted) {

        //error message detail
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
        });
      }
    }
  }

  //Handle logout
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

  // create map
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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

  //Logic for guest mode
  
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchSection(),
        _mapSection(),
        Padding(
          padding: const EdgeInsets.only(top: 15, left: 16, right: 16, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Doctors',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              //refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Doctors',
                onPressed: _fetchDoctors,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildDoctorList(),
        ),
      ],
    );
  }

  Widget _buildDoctorList() {
     if (_isLoadingDoctors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorLoadingDoctors != null) {
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
            ],
          ),
        ),
      );
    }

    if (_doctors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No doctors found at the moment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // display doctors in listview
    return ListView.builder(
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        return DoctorListItem(doctor: doctor);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Appointment'),
        centerTitle: true,
        actions: [
          if (!_isGuest && _loggedInUserId != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _handleLogout,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
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
        onTap: _onItemTapped,
      ),
    );
  }

  // map section
  Container _mapSection() {
     return Container(
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: double.infinity,
        height: 280, 
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _gaboroneCenter,
            zoom: 12.0,
          ),
          // Optional: Disable map interaction
          //mapToolbarEnabled: false,
          //scrollGesturesEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

    // search section - updated with controller and filter dropdown
  Container _searchSection() {
    return Container(
      margin: const EdgeInsets.only(top: 10, left: 20, right: 20),
      decoration: BoxDecoration(
        boxShadow: [
          const BoxShadow(
            color: Color.fromARGB(255, 207, 191, 193),
            blurRadius: 20,
            spreadRadius: 0.0,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController, // Assign the controller here
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(15),
          hintText: 'Search Doctor or Specialty...', // Updated hint text
          hintStyle: const TextStyle(color: Color(0xffDDDADA), fontSize: 14),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(15),
            child: Icon(Icons.search),
          ),
          suffixIcon: Row( // Use Row to keep clear button and filter button
            mainAxisSize: MainAxisSize.min, // Take only necessary space
            children: [
              // Clear button (appears when text is entered)
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  tooltip: 'Clear Search',
                  onPressed: () {
                    _searchController.clear();
                    // _onSearchChanged is called by the listener
                  },
                ),
                const SizedBox(
                 height: 30, // Adjust height as needed
                 child: VerticalDivider(
                   color: Colors.grey,
                   indent: 5,
                   endIndent: 5,
                   thickness: 0.7,
                 ),
              ),
              // Filter Dropdown Button
              PopupMenuButton<String?>( // Use String? for nullable value (All)
                icon: Icon(
                  Icons.filter_list,
                  // Indicate if a filter is active
                  color: _selectedSpecialtyFilter == null ? Colors.grey : Theme.of(context).primaryColor,
                ),
                tooltip: 'Filter by Specialty',
                onSelected: (String? selectedValue) {
                  // Update state and re-filter
                  setState(() {
                    _selectedSpecialtyFilter = selectedValue;
                  });
                  _filterDoctors(_searchController.text); // Re-apply filters
                },
                itemBuilder: (BuildContext context) {
                  // Get unique specialties
                  Set<String> specialties = _getUniqueSpecialties();

                  // Create menu items
                  List<PopupMenuEntry<String?>> menuItems = [];

                  // Add "All Specialties" option first
                  menuItems.add(
                    PopupMenuItem<String?>(
                      value: null, // Null value represents 'All'
                      child: Text(
                        'All Specialties',
                        style: TextStyle(
                          fontWeight: _selectedSpecialtyFilter == null
                              ? FontWeight.bold // Highlight if selected
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );

                  // Add separator
                  if (specialties.isNotEmpty) {
                     menuItems.add(const PopupMenuDivider());
                  }

                  // Add each unique specialty
                  for (String specialty in specialties) {
                    menuItems.add(
                      PopupMenuItem<String?>(
                        value: specialty,
                        child: Text(
                          specialty,
                           style: TextStyle(
                            fontWeight: _selectedSpecialtyFilter == specialty
                                ? FontWeight.bold // Highlight if selected
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }
                  return menuItems;
                },
              ),
              const SizedBox(width: 8), // Add some padding
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

}
