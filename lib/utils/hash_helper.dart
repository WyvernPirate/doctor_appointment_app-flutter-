// lib/utils/hash_helper.dart
import 'dart:convert'; // For utf8 encoding
import 'package:crypto/crypto.dart'; // For sha256

class HashHelper {
  static String hashPassword(String password) {
    // VERY BASIC HASHING - NO SALT. NOT RECOMMENDED FOR PRODUCTION.
    // A real implementation should use a strong algorithm (like Argon2, bcrypt)
    // and unique salts per user stored alongside the hash.
    final bytes = utf8.encode(password); // Encode password to bytes
    final digest = sha256.convert(bytes); // Hash using SHA-256
    return digest.toString(); // Return the hex string representation
  }

  static bool verifyPassword(String enteredPassword, String storedHash) {
    // Hash the entered password using the same method
    final hashedEnteredPassword = hashPassword(enteredPassword);
    // Compare the generated hash with the stored hash
    return hashedEnteredPassword == storedHash;
  }
}
