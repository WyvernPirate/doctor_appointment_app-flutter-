// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/theme_provider.dart';
import 'package:doctor_appointment_app/screens/auth_gate.dart'; // Import AuthGate

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print(".env file loaded successfully.");
  } catch (e) {
    print("CRITICAL ERROR: Failed to load .env file: $e");
    return; // Stop execution if .env fails
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    //Enable Firestore offline persistence (BEFORE any other Firestore operations)
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true,
      );
    print("Firebase initialized successfully.");
  } catch (e) {
    print("CRITICAL ERROR: Failed to initialize Firebase: $e");
    return;
  }

  // 4. Run the app LAST
  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeMode();

  runApp(
    ChangeNotifierProvider(create: (_) => themeProvider, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Define common text theme adjustments for better readability
    TextTheme commonTextTheme(TextTheme base) {
      return base.apply(
        bodyColor: base.bodyLarge?.color?.withOpacity(0.87),
        displayColor: base.displayLarge?.color?.withOpacity(0.87),
      );
    }

    // Define common icon theme
    IconThemeData commonIconTheme(IconThemeData base) {
      return base.copyWith(opacity: 0.87);
    }

    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,

      // --- Light Theme Configuration ---
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 1.0,
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          color: Colors.white,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey.shade200,
          selectedColor: Colors.blue.shade600,
          secondarySelectedColor: Colors.blue.shade600,
          labelStyle: TextStyle(color: Colors.black87),
          secondaryLabelStyle: TextStyle(color: Colors.white),
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
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          background: Colors.grey[900]!,
          surface: Colors.grey[850]!,
          onBackground: Colors.white.withOpacity(0.87),
          onSurface: Colors.white.withOpacity(0.87),
          primary: Colors.blue[300]!,
          onPrimary: Colors.black87,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white.withOpacity(0.87),
          elevation: 1.0,
        ),
        cardTheme: CardThemeData(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          color: Colors.grey[850],
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey.shade700,
          selectedColor: Colors.blue.shade400,
          secondarySelectedColor: Colors.blue.shade400,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.87)),
          secondaryLabelStyle: TextStyle(color: Colors.white),
          shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade600)),
          showCheckmark: false,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.grey[850],
          selectedItemColor: Colors.blue[300],
          unselectedItemColor: Colors.grey[500],
          elevation: 4.0,
        ),
        textTheme: commonTextTheme(ThemeData.dark().textTheme),
        iconTheme: commonIconTheme(ThemeData.dark().iconTheme),
        // Add other dark theme properties as needed
      ),

      themeMode: themeProvider.themeMode,
      home: const AuthGate(), // Use AuthGate to handle auth state and initial routing
    );
  }
}
