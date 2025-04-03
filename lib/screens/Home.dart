// Home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'InitLogin.dart'; // Import your login screen
import 'Appointments.dart'; // Import your Appointments screen
import 'Profile.dart'; // Import your Profile screen

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isGuest = false;
  int _selectedIndex = 0; // Track selected tab in bottom navigation

  // Sample doctor data (replace with your actual data)
  final List<Map<String, String>> _doctors = [
    {
      'name': 'Dr. John Doe',
      'speciality': 'Cardiologist',
      'image': 'assets/doctor1.jpg', // Replace with actual image paths
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
    // Add more doctors here...
  ];

  // Google Maps variables
  late GoogleMapController mapController;
  // Center on Gaborone, Botswana
  final LatLng _gaboroneCenter = const LatLng(-24.6545, 25.9086);

  @override
  void initState() {
    super.initState();
    _loadGuestStatus();
  }

  Future<void> _loadGuestStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGuest = prefs.getBool('isGuest') ?? false;
    });
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
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
                Navigator.of(context).pop(false); // Return false (don't logout)
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true (logout)
              },
            ),
          ],
        );
      },
    ) ?? false; // If dialog is dismissed, default to false

    // If user confirmed logout, proceed
    if (confirmLogout) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.setBool('isGuest', false); // Reset isGuest on logout

      // Navigate back to the login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const InitLogin()),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Function to build the body based on the selected index
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeScreenBody(); // Your current home screen content
      case 1:
        return const Appointments(); // Replace with your Appointments screen widget
      case 2:
        return const Profile(); // Replace with your Profile screen widget
      default:
        return _homeScreenBody(); // Default to home screen
    }
  }

  // Your original home screen content
  Widget _homeScreenBody() {
    return Column(
      children: [
        _isGuest
            ? const Text("You are in guest mode")
            : const Text("You are logged in"),
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
        // Doctor List Section
        Expanded(
          flex: 1,
          child: ListView.builder(
            itemCount: _doctors.length,
            itemBuilder: (context, index) {
              final doctor = _doctors[index];
              return ListTile(
                leading: CircleAvatar(
                  //backgroundImage: AssetImage(doctor['image']!),
                ),
                title: Text(doctor['name']!),
                subtitle: Text(doctor['speciality']!),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout, // Call the logout function
          ),
        ],
      ),
      body: _buildBody(), // Use the function to build the body
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
            zoom: 12.0, // Adjust the zoom level for Gaborone
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
