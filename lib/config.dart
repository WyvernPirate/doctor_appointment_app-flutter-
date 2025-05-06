import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Use a getter to access the environment variable
  static String get googleMapsApiKey {
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'YOUR_DEFAULT_OR_ERROR_KEY'; 
  }
}