import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/Home.dart'; // Import your Home screen
import 'screens/InitLogin.dart'; // Import your login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for shared_preferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false; // Get login status, default to false

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
   
    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const InitLogin() : const Home(), // Conditional navigation
    );
  }
}
