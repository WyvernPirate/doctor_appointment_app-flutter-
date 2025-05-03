# Doctor Appointment App (Flutter)

This project is a Flutter-based mobile application that allows patients to search for doctors, view their profiles, book appointments, and manage their appointments. It utilizes Google Maps for location-based doctor searches and Firebase for data storage and user authentication.

## Features

-   **Patient Side:**
    -   Search for doctors by specialty, name, and location.
    -   View doctor profiles with details, availability, and reviews.
    -   Book appointments.
    -   View and manage booked appointments.
    -   User authentication (login/registration).
    -   Google Maps integration for location-based doctor search.
-   **Doctor Side:**
    -   View and manage appointments.
    -   Manage availability.
    -   User authentication (login).

## Technologies Used

-   Flutter
-   Firebase (Firestore, Authentication)
-   Google Maps API for Flutter

## Setup Instructions

1.  **Clone the repository:**

    ```bash
    git clone [https://github.com/WyvernPirate/doctor-appointment-app-flutter.git](https://www.google.com/search?q=https://github.com/WyvernPirate/doctor-appointment-app-flutter.git)
    ```

2.  **Navigate to the project directory:**

    ```bash
    cd doctor-appointment-app-flutter
    ```

3.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

4.  **Set up Firebase:**
    -   Create a Firebase project on the Firebase Console.
    -   Add Firebase to your Flutter app using `flutterfire configure`.
    -   Enable Firestore and Authentication in your Firebase project.
    -   Replace `lib/firebase_options.dart` with your Firebase configuration.

5.  **Set up Google Maps API:**
    -   Obtain a Google Maps API key from the Google Cloud Console.
    -   Add the API key to your `AndroidManifest.xml` (Android) and `AppDelegate.swift` (iOS) files.

6.  **Run the app:**

    ```bash
    flutter run
    ```
## Project Structure

## TODO
- add lat and long to the doctor database so to be able to pick
- allow map integration on tapping
