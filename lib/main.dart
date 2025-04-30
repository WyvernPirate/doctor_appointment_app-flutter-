// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/Home.dart';
import 'screens/InitLogin.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    print(".env file loaded successfully."); 
  } catch (e) {
    print("Error loading .env file: $e"); 
  }


  // Initialize Firebase AFTER loading .env
  try {
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
     print("Firebase initialized successfully."); 
  } catch(e) {
     print("Error initializing Firebase: $e");
  }
 
  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeMode();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
   // Function to check if user session exists
  Future<bool> _checkUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('loggedInUserId') != null;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Define common text theme adjustments for better readability
    TextTheme commonTextTheme(TextTheme base) {
      return base.apply(
        bodyColor: base.bodyLarge?.color?.withOpacity(0.87), // Standard opacity for body text
        displayColor: base.displayLarge?.color?.withOpacity(0.87), // Standard opacity for display text
      );
    }

    // Define common icon theme
    IconThemeData commonIconTheme(IconThemeData base) {
       return base.copyWith(
         opacity: 0.87,
       );
    }

    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,

      // --- Light Theme Configuration ---
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue, 
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.grey[50], // Very light grey background
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue, // Standard blue app bar
          foregroundColor: Colors.white, // White text/icons on app bar
          elevation: 1.0,
        ),
        cardTheme: CardTheme(
           elevation: 1.5,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
           color: Colors.white, // Explicitly white cards
        ),
        chipTheme: ChipThemeData(
           backgroundColor: Colors.grey.shade200,
           selectedColor: Colors.blue.shade600,
           secondarySelectedColor: Colors.blue.shade600, // Ensure consistency
           labelStyle: TextStyle(color: Colors.black87),
           secondaryLabelStyle: TextStyle(color: Colors.white), // Text color when selected
           shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
           showCheckmark: false,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey[600],
          elevation: 4.0,
        ),
        textTheme: commonTextTheme(ThemeData.light().textTheme),
        iconTheme: commonIconTheme(ThemeData.light().iconTheme),
        // Add other light theme properties as needed
      ),

      // --- Dark Theme Configuration ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
           seedColor: Colors.blue, // Base color
           brightness: Brightness.dark,
           // Override specific colors for a greyish look
           background: Colors.grey[900]!, // Dark grey background
           surface: Colors.grey[850]!, // Slightly lighter surface for cards/dialogs
           onBackground: Colors.white.withOpacity(0.87), // Text on background
           onSurface: Colors.white.withOpacity(0.87), // Text on surfaces
           primary: Colors.blue[300]!, // Lighter blue for primary elements
           onPrimary: Colors.black87, // Text on primary color
        ),
        scaffoldBackgroundColor: Colors.grey[900], // Dark grey background
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850], // Slightly lighter grey for app bar
          foregroundColor: Colors.white.withOpacity(0.87), // Text/icons on app bar
          elevation: 1.0,
        ),
         cardTheme: CardTheme(
           elevation: 2.0,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
           color: Colors.grey[850], // Use surface color from ColorScheme
        ),
        chipTheme: ChipThemeData(
           backgroundColor: Colors.grey.shade700, // Darker grey for unselected chips
           selectedColor: Colors.blue.shade400, // Slightly brighter blue for selected
           secondarySelectedColor: Colors.blue.shade400,
           labelStyle: TextStyle(color: Colors.white.withOpacity(0.87)),
           secondaryLabelStyle: TextStyle(color: Colors.white), // Text color when selected
           shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade600)),
           showCheckmark: false,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.grey[850], // Match app bar
          selectedItemColor: Colors.blue[300], // Lighter blue for selected item
          unselectedItemColor: Colors.grey[500], // Lighter grey for unselected
          elevation: 4.0,
        ),
        textTheme: commonTextTheme(ThemeData.dark().textTheme),
        iconTheme: commonIconTheme(ThemeData.dark().iconTheme),
        // Add other dark theme properties as needed
      ),

      themeMode: themeProvider.themeMode,
      home: FutureBuilder<bool>(
        future: _checkUserSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData && snapshot.data == true) {
            return const Home();
          } else {
            return const InitLogin();
          }
        },
      ),
    );
  }
}
