// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/Home.dart';
import 'screens/InitLogin.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Create the ThemeProvider instance *before* running the app
  final themeProvider = ThemeProvider();
  // Ensure the theme is loaded from prefs before the UI builds
  await themeProvider.loadThemeMode();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeProvider, // Provide the instance
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
    // Consume the provider to get the current theme mode
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Doctor Appointment App',
       debugShowCheckedModeBanner: false,
      theme: ThemeData( // light theme configuration
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData( // dark theme configuration
        brightness: Brightness.dark,
        primarySwatch: Colors.blue, 
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
