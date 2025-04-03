// Appointments.dart
import 'package:flutter/material.dart';

class Appointments extends StatefulWidget {
  const Appointments({super.key});

  @override
  State<Appointments> createState() => _AppointmentsState();
}

class _AppointmentsState extends State<Appointments> {
  // Sample appointment data (replace with data from Firebase later)
  List<Map<String, String>> _appointments = [
    {
      'doctor': 'Dr. John Doe',
      'specialty': 'Cardiologist',
      'date': '2024-03-15',
      'time': '10:00 AM',
      'status': 'Confirmed',
    },
    {
      'doctor': 'Dr. Jane Smith',
      'specialty': 'Dermatologist',
      'date': '2024-03-20',
      'time': '02:30 PM',
      'status': 'Pending',
    },
    {
      'doctor': 'Dr. David Lee',
      'specialty': 'Pediatrician',
      'date': '2024-03-25',
      'time': '11:15 AM',
      'status': 'Confirmed',
    },
    // Add more appointments here...
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Appointments'),
        centerTitle: true,
      ),
      body: _appointments.isEmpty
          ? const Center(
              child: Text('No appointments scheduled.'),
            )
          : ListView.builder(
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appointment = _appointments[index];
                return _buildAppointmentCard(appointment);
              },
            ),
    );
  }

  // Helper function to build an appointment card
  Widget _buildAppointmentCard(Map<String, String> appointment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment['doctor']!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('Specialty: ${appointment['specialty']}'),
            const SizedBox(height: 4),
            Text('Date: ${appointment['date']}'),
            const SizedBox(height: 4),
            Text('Time: ${appointment['time']}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildStatusBadge(appointment['status']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build a status badge
  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status.toLowerCase()) {
      case 'confirmed':
        badgeColor = Colors.green;
        break;
      case 'pending':
        badgeColor = Colors.orange;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
