import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/Home.dart'; // Import your Home screen
import 'screens/InitLogin.dart'; // Import your login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for shared_preferences
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Check login status


  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false; // Get login status, default to false
  bool isGuest = prefs.getBool('isGuest') ?? false; // Get guest status, default to false

  runApp(MyApp(isLoggedIn: isLoggedIn, isGuest: isGuest));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isGuest;

  const MyApp({super.key, required this.isLoggedIn, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: isLoggedIn || isGuest
          ? const Home()
          : const InitLogin(), // Conditional navigation
    );
  }
}
