// Home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'InitLogin.dart'; // Import your login screen

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isGuest = false;

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
      //SharedPreferences prefs = await SharedPreferences.getInstance();
      //await prefs.setBool('isLoggedIn', false);
      //await prefs.setBool('isGuest', false); // Reset isGuest on logout

      // Navigate back to the login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const InitLogin()),
      );
    }
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
      body: Column(children: [
        _searchSection(),
        _isGuest
            ? const Text("You are in guest mode")
            : const Text("You are logged in")
      ]),
    );
  }

  Column _searchSection() {
    return Column();
  }
}
