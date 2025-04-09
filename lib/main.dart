// main.dart
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Remove firebase_auth and firebase_app_check imports

import 'firebase_options.dart';
import 'screens/Home.dart';
import 'screens/InitLogin.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Remove App Check activation

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Function to check if user session exists
  Future<bool> _checkUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Check if we stored a user ID locally after successful Firestore login
    return prefs.getString('loggedInUserId') != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<bool>(
        future: _checkUserSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData && snapshot.data == true) {
            // User session found (user ID stored locally)
            return const Home();
          } else {
            // No user session, go to login
            return const InitLogin();
          }
        },
      ),
    );
  }
}

