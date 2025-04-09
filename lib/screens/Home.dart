// Home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Remove firebase_auth import
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
  String? _loggedInUserId; // Store user ID to differentiate logged-in from guest

  final List<Map<String, String>> _doctors = [
    {
      'name': 'Dr. John Doe',
      'speciality': 'Cardiologist',
      'image': 'assets/doctor1.jpg',
    },
    {
      'name': 'Dr. Jane Smith',
      'speciality': 'Dermatologist',
      'image': 'assets/doctor2.jpg',
    },
    {
      'name': 'Dr. David Lee',
      'speciality': 'Pediatrician',
      'image': 'assets/doctor3.jpg',
    },
    // ... doctor data ...
  ];

  // Google Maps variables - remain the same
  late GoogleMapController mapController;
  final LatLng _gaboroneCenter = const LatLng(-24.6545, 25.9086);

  @override
  void initState() {
    super.initState();
    _loadUserStatus(); // Renamed for clarity
  }

  // Load both guest status and logged-in user ID
  Future<void> _loadUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _isGuest = prefs.getBool('isGuest') ?? false;
      _loggedInUserId = prefs.getString('loggedInUserId'); // Check if a user ID exists
    });
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog - remains the same
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
        ) ?? false;

    if (confirmLogout) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // *** Remove the loggedInUserId to signify logout ***
      await prefs.remove('loggedInUserId');
      // Explicitly set isGuest to false when logging out
      await prefs.setBool('isGuest', false);
      // *** Remove FirebaseAuth.instance.signOut() ***

      // Navigate back to Login screen - remains the same
      // Use mounted check before navigation
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const InitLogin()),
      );
    }
  }

  // _onMapCreated - remains the same
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // _onItemTapped - remains the same
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Function to build the body based on the selected index - remains the same
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeScreenBody();
      case 1:
        // Only show Appointments if logged in (not guest)
        return _isGuest ? _guestModeNotice("view appointments") : const Appointments();
      case 2:
        // Only show Profile if logged in (not guest)
        return _isGuest ? _guestModeNotice("view your profile") : const Profile();
      default:
        return _homeScreenBody();
    }
  }

  // Helper widget for guest mode restriction
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
                // Navigate to login
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
    // UI remains largely the same, but the top text can be more specific
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _isGuest ? "Browsing as Guest" : "Welcome!", // More specific text
            style: TextStyle(fontSize: 16, color: _isGuest ? Colors.orange : Colors.green),
          ),
        ),
        _searchSection(),
        _mapSection(),
        Container(
          margin: const EdgeInsets.only(top: 10, left: 10),
          alignment: Alignment.topLeft,
          child: const Text(
            'Doctors:',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
        ),
        // Doctor List Section - remains the same
        Expanded(
          flex: 1,
          child: ListView.builder(
            itemCount: _doctors.length,
            itemBuilder: (context, index) {
              final doctor = _doctors[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage(doctor['image']!), // Assuming you have assets
                //  onBackgroundImageError: (_, __) {}, // Handle missing assets
                ),
                title: Text(doctor['name']!),
                subtitle: Text(doctor['speciality']!),
                // Add onTap later for booking
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        centerTitle: true,
        actions: [
          // Only show logout button if the user is actually logged in (not guest)
          if (!_isGuest && _loggedInUserId != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout', // Add tooltip
              onPressed: _handleLogout,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }

  // _mapSection - remains the same
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

  // _searchSection - remains the same
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
