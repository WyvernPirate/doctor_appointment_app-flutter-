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

  // --- Firestore Doctor Data State ---
  List<Doctor> _doctors = [];
  bool _isLoadingDoctors = true;
  String? _errorLoadingDoctors;
  // --- End Firestore Doctor Data State ---

  late GoogleMapController mapController;
  final LatLng _gaboroneCenter = const LatLng(-24.6545, 25.9086);

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
    _fetchDoctors();
  }
// load the user status
  Future<void> _loadUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isGuest = prefs.getBool('isGuest') ?? false;
      _loggedInUserId = prefs.getString('loggedInUserId');
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
      print(stackTrace);
      if (mounted) {
        setState(() {
          _errorLoadingDoctors = 'Failed to load doctors. Please try again.';
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _isGuest ? "Browsing as Guest" : "Welcome!",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _isGuest ? Colors.orangeAccent : Colors.blueAccent),
          ),
        ),
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
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(15),
          hintText: 'Search for Doctor, Place, Specialists...',
          hintStyle: const TextStyle(color: Color(0xffDDDADA), fontSize: 14),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(15),
            child: Icon(Icons.search),
          ),
          suffixIcon: SizedBox(
            width: 100,
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const VerticalDivider(
                    color: Colors.black,
                    indent: 10,
                    endIndent: 10,
                    thickness: 0.7,
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.filter_list),
                  ),
                ],
              ),
            ),
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
